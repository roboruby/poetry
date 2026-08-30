# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    class RegistryTest < Minitest::Test
      # The requires_content shape: one declaration drives the
      # runtime raise AND the registry's static contract.
      module ContentProbe
        class Component < Poetry::Core::Component
          requires_content "the probe body"

          def call
            content_tag(:span, content)
          end
        end
      end

      # use_stimulus declarations feed the registry's controllers section
      # directly (the constant scan remains for unmigrated components).
      module DeclaredProbe
        class Component < Poetry::Core::Component
          use_stimulus do
            on :root do
              controller(:accordion) { register }
              controller("host-thing") { register }
            end
          end

          def call
            content_tag(:div, content, **stimulus_attributes_for(:root))
          end
        end
      end

      # tool declarations feed the registry's tools section (the operate
      # surface), MCP Tool-shaped with the resolved dispatch descriptor.
      module ToolProbe
        class Component < Poetry::Core::Component
          use_stimulus do
            on :root do
              controller(:accordion) { register }
            end
          end

          tool :toggle_section, description: "Expand or collapse the section.",
                                params: { value: { type: "string", required: true } },
                                executes: :toggle, mutating: true

          def call
            content_tag(:div, content, **stimulus_attributes_for(:root))
          end
        end
      end

      def registry
        # Explicit component list: descendant discovery inside the test suite
        # would pick up test-defined probe components.
        Registry.new(components: [Poetry::Core::X::Component, Poetry::Core::Generic::Component])
      end

      # Defines a probe whose const_source_location is a REAL file with
      # controlled content - the identity derivation scans ancestor
      # sources, so probes defined inline would all share this test
      # file's text (which mentions the funnel).
      def eval_probe(dir, name, code)
        path = File.join(dir, "#{name}.rb")
        File.write(path, code)
        eval(File.read(path), TOPLEVEL_BINDING, path, 1) # rubocop:disable Security/Eval
      end

      def test_entries_are_keyed_by_component_path
        assert_equal %w[poetry/core/generic poetry/core/x], registry.entries.keys.sort
      end

      def test_controllers_come_from_use_stimulus_declarations
        entry = Registry.new(components: [DeclaredProbe::Component])
                        .entries.fetch("poetry/core/registry_test/declared_probe")
        controllers = entry.fetch("controllers")

        assert_equal(["poetry--core--accordion"], controllers.map { |c| c["identifier"] })
        assert_includes controllers.first["actions"], "toggle"
      end

      def test_tools_come_from_tool_declarations
        entry = Registry.new(components: [ToolProbe::Component])
                        .entries.fetch("poetry/core/registry_test/tool_probe")
        tool = entry.fetch("tools").fetch(0)

        assert_equal "toggle_section", tool["name"]
        assert_equal "poetry--core--accordion#toggle", tool["executes"]
        assert_equal ["value"], tool.dig("inputSchema", "required")
        assert_equal({ "readOnlyHint" => false, "untrustedContentHint" => false }, tool["annotations"])
        refute registry.entries.fetch("poetry/core/x").key?("tools")
      end

      def test_entry_carries_the_introspected_surface
        entry = registry.entries.fetch("poetry/core/x")

        assert_equal "Poetry::Core::X::Component", entry["class_name"]
        assert_equal "poetry-core-x", entry["bem_block"]
        color = entry["styles"].find { |style| style["name"] == "color" }

        assert_includes color["variants"], "indigo"
        assert_equal "indigo", color["default"]
        assert_equal Poetry::Core::X::Style.capsule, entry["capsule"]
      end

      def test_identity_is_false_for_components_that_never_mint
        entry = registry.entries.fetch("poetry/core/x")

        assert entry.key?("identity"), "the derived fact must be emitted, not just absent"
        refute entry["identity"], "X's family never reaches poetry_instance_id"
      end

      def test_identity_is_absent_when_the_class_source_reaches_the_funnel
        Dir.mktmpdir do |dir|
          eval_probe(dir, "minting_probe", <<~RUBY)
            module IdentityMintingProbe
              class Component < Poetry::Core::Component
                def call
                  content_tag(:div, content, id: poetry_instance_id("probe"))
                end
              end
            end
          RUBY

          entry = Registry.new(components: [::IdentityMintingProbe::Component]).entries.values.first

          refute entry.key?("identity"), "a funnel call in the class's own source = minting"
        end
      end

      def test_identity_sees_family_modules_below_the_base_class
        Dir.mktmpdir do |dir|
          eval_probe(dir, "family_module", <<~RUBY)
            module IdentityFamilyProbe
              module Identity
                def instance_id = (@instance_id ||= poetry_instance_id("fam"))
              end
            end
          RUBY
          eval_probe(dir, "family_component", <<~RUBY)
            module IdentityFamilyProbe
              class Component < Poetry::Core::Component
                include Identity

                def call = content_tag(:div, content)
              end
            end
          RUBY

          entry = Registry.new(components: [::IdentityFamilyProbe::Component]).entries.values.first

          refute entry.key?("identity"), "the module's source carries the funnel for its includers"
        end
      end

      def test_identity_constant_overrides_the_derivation
        Dir.mktmpdir do |dir|
          eval_probe(dir, "override_probe", <<~RUBY)
            module IdentityOverrideProbe
              class Component < Poetry::Core::Component
                # Composition: the rendered DOM carries ids minted by the
                # components this one renders.
                IDENTITY = true

                def call = content_tag(:div, content)
              end
            end
          RUBY

          entry = Registry.new(components: [::IdentityOverrideProbe::Component]).entries.values.first

          refute entry.key?("identity"), "IDENTITY = true forces minting for compositional DOMs"
        end
      end

      def test_yaml_is_plain_data_with_no_ruby_tags
        yaml = registry.to_yaml

        refute_includes yaml, "!ruby", "symbols must be stringified for language-agnostic consumers"
        parsed = YAML.safe_load(yaml)

        assert parsed["components"].key?("poetry/core/x")
      end

      def test_generate_and_verify_round_trip
        Dir.mktmpdir do |dir|
          refute registry.verified?(root: dir), "missing registry must not verify"
          registry.generate!(root: dir)

          assert registry.verified?(root: dir)

          File.write(File.join(dir, Registry::RELATIVE_PATH), "components: {}\n")

          refute registry.verified?(root: dir), "tampering must be detected"
        end
      end

      def test_committed_reads_the_generated_sections_boot_free
        Dir.mktmpdir do |dir|
          registry.generate!(root: dir)
          committed = Registry.committed(dir)

          assert_equal registry.entries.keys, committed.entries.keys
          assert_equal Pathname.new(dir), committed.source_root
          assert_nil committed.blocks, "a registry generated without blocks reads back without them"
        end
      end

      def test_helpers_section_is_emitted_when_given_and_absent_otherwise
        contracts = {
          "poetry_widget_addon" => {
            "options" => [{ "name" => "align", "type" => :symbol, "variants" => %i[inline-start inline-end] }]
          },
          "poetry_widget_group" => {}
        }
        with_helpers = Registry.new(components: [Poetry::Core::X::Component], helpers: contracts)
        parsed = YAML.safe_load(with_helpers.to_yaml)

        assert_equal %w[poetry_widget_addon poetry_widget_group], parsed["helpers"].keys
        align = parsed.dig("helpers", "poetry_widget_addon", "options").first

        assert_equal %w[inline-start inline-end], align["variants"], "helper contracts must be plain data"
        refute_includes with_helpers.to_yaml, "!ruby"
        refute YAML.safe_load(registry.to_yaml).key?("helpers"), "no helpers given means no helpers key"
      end

      def test_blocks_section_is_emitted_when_given_and_absent_otherwise
        blocks = {
          "data-index" => { "title" => "Data index", "description" => "A records screen.",
                            "components" => %w[badge table], "template" => "blocks/data_index.html.erb" }
        }
        with_blocks = Registry.new(components: [Poetry::Core::X::Component], blocks: blocks)
        parsed = YAML.safe_load(with_blocks.to_yaml)

        assert_equal %w[badge table], parsed.dig("blocks", "data-index", "components")
        assert_equal "blocks/data_index.html.erb", parsed.dig("blocks", "data-index", "template")
        refute YAML.safe_load(registry.to_yaml).key?("blocks"), "no blocks given means no blocks key"
      end

      def test_requires_content_is_emitted_when_declared_and_absent_otherwise
        entries = Registry.new(components: [ContentProbe::Component, Poetry::Core::X::Component]).entries
        probe = entries.fetch(ContentProbe::Component.component_path)

        assert_equal "the probe body", probe["requires_content"]
        refute entries.fetch("poetry/core/x").key?("requires_content"),
               "no declaration means no requirement claimed"
      end

      def test_ensure_content_raises_the_declared_hint
        component = ContentProbe::Component.new
        def component.content? = false
        error = assert_raises(ArgumentError) { component.ensure_content! }

        assert_equal "ContentProbe requires a content block (the probe body)", error.message
        def component.content? = true

        assert_nil component.ensure_content!
      end

      def test_committed_registry_is_in_sync_with_source
        # The CI drift gate as a unit test: default discovery filters to
        # components whose source lives in this gem, so the set is identical
        # here and under the rake task's fresh boot.
        assert_predicate Registry.new, :verified?,
                         "committed component registry drifted - run `bin/rake registry:generate` and commit"
      end

      # The internal-component marker: full Component machinery without a
      # registry entry (discovery rejects the flag; every registry-derived
      # surface follows). Inherited so nested subclasses stay internal.
      def test_internal_component_marker_semantics
        refute Poetry::Core::Component.internal_component,
               "the base class must not be internal (it would blank discovery)"

        internal = Class.new(Poetry::Core::Component) { internal_component! }
        nested = Class.new(internal)
        regular = Class.new(Poetry::Core::Component)

        assert internal.internal_component
        assert nested.internal_component, "internal is inherited"
        refute regular.internal_component
      end
    end
  end
end
