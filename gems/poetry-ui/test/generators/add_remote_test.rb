# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/poetry/add/add_generator"

module Poetry
  # The ecosystem address path of poetry:add, end-to-end over FILE
  # addresses - the same resolve/validate/write
  # pipeline url and @namespace addresses ride, with no network in the
  # suite (the client's remote conduct is covered in poetry-core).
  class AddRemoteGeneratorTest < Rails::Generators::TestCase
    tests Poetry::AddGenerator
    destination File.expand_path("../tmp/add-remote-dest", __dir__)
    setup :prepare_destination

    WIDGET = {
      "name" => "fancy-widget",
      "type" => "registry:component",
      "registryDependencies" => ["button", "@poetry/app-shell", "widget-helper"],
      "dependencies" => %w[rails acme_sdk],
      "files" => [
        { "path" => "app/components/acme/fancy_widget/component.rb",
          "content" => "class Acme::FancyWidget::Component < Poetry::Core::Component\nend\n" }
      ],
      "cssVars" => { "light" => { "widget-accent" => "oklch(0.6 0.1 250)" } },
      "css" => ".acme-widget { color: var(--widget-accent); }",
      "docs" => "Set config.acme_sdk_key before first render."
    }.freeze

    HELPER = {
      "name" => "widget-helper",
      "type" => "registry:lib",
      "files" => [
        { "path" => "app/helpers/acme/widget_helper.rb",
          "content" => "module Acme::WidgetHelper\nend\n" }
      ]
    }.freeze

    def write_fixture(name, payload)
      dir = File.join(destination_root, "items")
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "#{name}.json"), JSON.generate(payload))
    end

    def prepare_remote_fixtures
      write_fixture("fancy-widget", WIDGET)
      write_fixture("widget-helper", HELPER)
      FileUtils.mkdir_p(File.join(destination_root, "app/assets/tailwind"))
      File.write(File.join(destination_root, "app/assets/tailwind/application.css"),
                 %(@import "tailwindcss";\n))
    end

    def test_a_file_address_installs_the_item_its_remote_deps_and_nothing_the_gems_provide
      prepare_remote_fixtures
      run_generator %w[./items/fancy-widget.json]

      # The item + its sibling-resolved remote dep land; the write set is
      # topo-ordered so the helper exists before the widget that needs it.
      assert_file "app/components/acme/fancy_widget/component.rb", /FancyWidget/
      assert_file "app/helpers/acme/widget_helper.rb", /WidgetHelper/
      # button is gem-satisfied: provided at runtime, never copied.
      assert_no_file "app/components/poetry/ui/button/component.rb"
      # @poetry/app-shell is a copy-in block: installed via its own generator.
      assert_file "app/views/blocks/_app_shell.html.erb", /this file is yours/
    end

    def test_css_merges_into_a_community_file_and_the_tailwind_entry
      prepare_remote_fixtures
      run_generator %w[./items/fancy-widget.json]

      assert_file "app/assets/tailwind/poetry/community/fancy-widget.css" do |css|
        assert_match(/--widget-accent: oklch\(0.6 0.1 250\);/, css)
        assert_match(/\.acme-widget \{ color: var\(--widget-accent\); \}/, css)
      end
      assert_file "app/assets/tailwind/application.css",
                  %r{@import "\./poetry/community/fancy-widget\.css";}
    end

    def test_provenance_lands_in_the_manifest_and_registries_config_survives
      prepare_remote_fixtures
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(File.join(destination_root, "config/poetry_components.yml"),
                 YAML.dump({ "registries" => { "@acme" => "https://acme.dev/r/{name}.json" },
                             "components" => {} }))
      run_generator %w[./items/fancy-widget.json]

      assert_file "config/poetry_components.yml" do |manifest|
        parsed = YAML.safe_load(manifest)

        assert_equal "./items/fancy-widget.json", parsed.dig("components", "fancy-widget", "source")
        assert_equal "./items/widget-helper.json", parsed.dig("components", "widget-helper", "source")
        assert_equal "https://acme.dev/r/{name}.json", parsed.dig("registries", "@acme"),
                     "a manifest rewrite must never drop the registries config"
      end
    end

    def test_reruns_never_clobber_local_edits
      prepare_remote_fixtures
      run_generator %w[./items/fancy-widget.json]
      local = File.join(destination_root, "app/components/acme/fancy_widget/component.rb")
      File.write(local, "# customized\n")

      run_generator %w[./items/fancy-widget.json]

      assert_equal "# customized\n", File.read(local)
    end

    def test_a_traversal_target_aborts_before_any_write
      write_fixture("evil", { "name" => "evil", "type" => "registry:component",
                              "files" => [{ "path" => "x.rb", "content" => "boom",
                                            "target" => "config/initializers/evil.rb" }] })

      assert_raises(Poetry::Core::RegistryInstaller::Error) { run_generator %w[./items/evil.json] }
      assert_no_file "config/initializers/evil.rb"
    end

    def test_local_blocks_install_through_poetry_add_too
      run_generator %w[app-shell]

      assert_file "app/views/blocks/_app_shell.html.erb"
    end

    def test_local_component_copies_include_nested_subcomponents_and_subdirs
      run_generator %w[Command Tooltip]

      assert_file "app/components/poetry/ui/command/component.rb"
      # command/dialog rides along (the sibling-file nesting convention).
      assert_file "app/components/poetry/ui/command/dialog_component.rb"
      # tooltip has a real previews/ SUBDIRECTORY - the recursive copy fix
      # (the old flat glob EISDIR-crashed reading the directory entry).
      assert_file "app/components/poetry/ui/tooltip/previews/provider_row.html.erb"
    end
  end
end
