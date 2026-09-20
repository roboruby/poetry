# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class RegistryInstallerTest < Minitest::Test
      # A client double: items by address raw, recording resolution order.
      class FakeClient
        attr_reader :resolved

        def initialize(items)
          @items = items
          @resolved = []
        end

        def resolve(address)
          @resolved << address.raw
          @items.fetch(address.raw) { raise RegistryClient::Error, "no item at #{address.raw}" }
        end
      end

      def item(name, files: nil, deps: [], **extra)
        files ||= [{ "path" => "app/components/acme/#{name.tr("-", "_")}.rb",
                     "content" => "# #{name}\n" }]
        { "name" => name, "type" => "registry:component",
          "files" => files, "registryDependencies" => deps }.merge(extra)
      end

      def build_installer(items, local_components: %w[button icon], local_blocks: %w[app-shell],
                          loaded_gems: %w[rails])
        client = FakeClient.new(items)
        installer = RegistryInstaller.new(client: client, destination_root: "/host/app",
                                          local_components: local_components,
                                          local_blocks: local_blocks, loaded_gems: loaded_gems)
        [installer, client]
      end

      def address(raw)
        RegistryAddress.parse(raw)
      end

      def test_a_single_item_plans_its_writes_and_provenance
        installer, = build_installer({ "@acme/fancy-chart" => item("fancy-chart") })
        plan = installer.plan([address("@acme/fancy-chart")])

        assert_equal ["app/components/acme/fancy_chart.rb"], plan.writes.map(&:target)
        assert_equal({ "fancy-chart" => { "source" => "@acme/fancy-chart" } }, plan.manifest)
      end

      def test_poetry_gem_components_satisfy_at_runtime_with_no_copy
        installer, client = build_installer(
          { "@acme/fancy-chart" => item("fancy-chart", deps: ["button", "@poetry/icon"]) }
        )
        plan = installer.plan([address("@acme/fancy-chart")])

        assert_equal %w[button icon], plan.gem_satisfied
        assert_equal ["@acme/fancy-chart"], client.resolved, "gem-satisfied deps must not fetch"
        assert_equal 1, plan.writes.size
      end

      def test_gem_blocks_install_through_their_own_generator
        installer, = build_installer({ "@acme/dash" => item("dash", deps: ["@poetry/app-shell"]) })
        plan = installer.plan([address("@acme/dash")])

        assert_equal %w[app-shell], plan.block_installs
      end

      def test_bare_deps_resolve_as_siblings_and_write_in_topo_order
        installer, client = build_installer(
          { "@acme/a" => item("a", deps: %w[b]),
            "@acme/b" => item("b") }
        )
        plan = installer.plan([address("@acme/a")])

        assert_includes client.resolved, "@acme/b", "bare dep must resolve in the parent's namespace"
        assert_equal ["app/components/acme/b.rb", "app/components/acme/a.rb"],
                     plan.writes.map(&:target), "dependencies write before dependents"
      end

      def test_an_unsatisfiable_poetry_dep_raises
        installer, = build_installer({ "@acme/x" => item("x", deps: ["@poetry/no-such-thing"]) })
        error = assert_raises(RegistryInstaller::Error) { installer.plan([address("@acme/x")]) }

        assert_match(/not provided by the installed poetry gems/, error.message)
      end

      def test_cycles_are_named_not_spun
        installer, = build_installer(
          { "@acme/a" => item("a", deps: %w[b]),
            "@acme/b" => item("b", deps: %w[a]) }
        )
        error = assert_raises(RegistryInstaller::Error) { installer.plan([address("@acme/a")]) }

        assert_match(/dependency cycle among: a, b/, error.message)
      end

      def test_diamond_deps_dedupe_and_identical_writes_collapse
        shared = item("shared")
        installer, = build_installer(
          { "@acme/a" => item("a", deps: %w[shared]),
            "@acme/b" => item("b", deps: %w[shared]),
            "@acme/shared" => shared }
        )
        plan = installer.plan([address("@acme/a"), address("@acme/b")])

        assert_equal 3, plan.writes.size, "shared writes once"
      end

      def test_same_name_different_content_is_a_collision
        installer, = build_installer(
          { "@acme/x" => item("x"),
            "https://other.dev/r/x.json" => item("x", files: [{ "path" => "app/components/acme/x.rb",
                                                                "content" => "# different\n" }]) }
        )
        error = assert_raises(RegistryInstaller::Error) do
          installer.plan([address("@acme/x"), address("https://other.dev/r/x.json")])
        end

        assert_match(/different content/, error.message)
      end

      def test_traversal_and_out_of_root_targets_are_refused
        %w[
          ../evil.rb
          /etc/passwd
          app/components/../../evil.rb
          config/initializers/hack.rb
          ~/x.rb
        ].each do |target|
          installer, = build_installer(
            { "@acme/x" => item("x", files: [{ "path" => "x.rb", "content" => "", "target" => target }]) }
          )
          error = assert_raises(RegistryInstaller::Error, "#{target} must be refused") do
            installer.plan([address("@acme/x")])
          end

          assert_match(/refusing target/, error.message)
        end
      end

      def test_css_vars_and_css_merge_into_one_community_file
        installer, = build_installer(
          { "@acme/x" => item("x", "cssVars" => { "light" => { "brand" => "oklch(0.5 0.2 250)" },
                                                  "dark" => { "brand" => "oklch(0.7 0.2 250)" } },
                                   "css" => ".fancy { color: var(--brand); }") }
        )
        plan = installer.plan([address("@acme/x")])

        assert_equal(["app/assets/tailwind/poetry/community/x.css"], plan.css_writes.map { |css| css[:path] })
        content = plan.css_writes.first[:content]

        assert_match(/:root \{\n  --brand: oklch\(0.5 0.2 250\);\n\}/, content)
        assert_match(/\.dark \{/, content)
        assert_match(/\.fancy \{ color: var\(--brand\); \}/, content)
        assert_equal [%(@import "./poetry/community/x.css";)], plan.entry_lines
      end

      def test_gem_dependencies_are_reported_never_installed
        installer, = build_installer(
          { "@acme/x" => item("x", "dependencies" => ["rails", "some_missing_gem", "pinned@1.2"]) }
        )
        plan = installer.plan([address("@acme/x")])

        assert_equal ["some_missing_gem", "pinned@1.2"], plan.gem_deps
      end

      def test_docs_strings_surface_in_the_plan
        installer, = build_installer({ "@acme/x" => item("x", "docs" => "Wire the webhook in config/acme.rb") })

        assert_equal ["Wire the webhook in config/acme.rb"], installer.plan([address("@acme/x")]).docs
      end
    end
  end
end
