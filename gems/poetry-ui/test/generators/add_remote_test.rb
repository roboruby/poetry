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

    def test_an_item_with_a_stimulus_controller_refreshes_the_controllers_manifest
      controller = <<~JS
        import { Controller } from "@hotwired/stimulus"

        export default class extends Controller {
          static targets = ["count"]
          static values = { step: Number }

          tick() {}
        }
      JS
      write_fixture("ticker", { "name" => "ticker", "type" => "registry:component",
                                "files" => [{ "path" => "app/javascript/controllers/acme/ticker_controller.js",
                                              "content" => controller }] })
      output = run_generator %w[./items/ticker.json]

      assert_match(%r{stimulus.*config/controllers_manifest.json \(1 controller\)}, output)
      assert_file "config/controllers_manifest.json" do |manifest|
        entry = JSON.parse(manifest).fetch("acme--ticker")

        assert_equal ["count"], entry["targets"]
        assert_includes entry["methods"], "tick"
      end
    end

    # A bundle credits every library inside it: several origins, each with
    # its own notice.
    BUNDLE_ITEM = {
      "name" => "editor-island", "type" => "registry:component",
      "meta" => {
        "community" => true,
        "source" => { "registry" => "@tiptap", "item" => "react", "url" => "https://www.npmjs.com/package/@tiptap/react",
                      "repository" => "https://github.com/ueberdosis/tiptap", "license" => "MIT",
                      "copyright" => "Copyright (c) 2025, Tiptap GmbH", "notice" => "MIT License (Tiptap)" },
        "sources" => [
          { "registry" => "@tiptap", "item" => "react", "url" => "https://www.npmjs.com/package/@tiptap/react",
            "repository" => "https://github.com/ueberdosis/tiptap", "license" => "MIT",
            "copyright" => "Copyright (c) 2025, Tiptap GmbH", "notice" => "MIT License (Tiptap)" },
          { "registry" => "@react", "item" => "react", "url" => "https://www.npmjs.com/package/react",
            "repository" => "https://github.com/facebook/react", "license" => "MIT",
            "copyright" => "Copyright (c) Meta Platforms, Inc. and affiliates.", "notice" => "MIT License (React)" }
        ]
      },
      "files" => [{ "path" => "app/javascript/community/islands/editor.js",
                    "content" => "export function mount() {}\n" }]
    }.freeze

    def test_a_bundle_credits_every_origin_in_the_notices_and_lists_them_in_the_manifest
      prepare_community
      write_fixture("editor-island", BUNDLE_ITEM)

      output = run_generator %w[@poetry/editor-island]

      assert_match(%r{adapted from @tiptap/react \(MIT\), @react/react \(MIT\)}, output)
      assert_file "THIRD_PARTY_NOTICES.md" do |notices|
        assert_equal 1, notices.scan("<!-- poetry:add editor-island -->").size
        assert_includes notices, "Adapted from @tiptap/react"
        assert_includes notices, "Adapted from @react/react"
        assert_includes notices, "MIT License (React)"
      end
      assert_file "config/poetry_components.yml" do |manifest|
        entry = YAML.safe_load(manifest, permitted_classes: [Date]).dig("components", "editor-island")

        assert_nil entry["origin"]
        assert_equal(%w[@tiptap @react], entry["origins"].map { |origin| origin["registry"] })
        assert(entry["origins"].none? { |origin| origin.key?("notice") })
      end
    end

    MODULE_ITEM = {
      "name" => "mesh-island", "type" => "registry:component", "meta" => { "community" => true },
      "files" => [{ "path" => "app/javascript/community/islands/mesh.js",
                    "content" => "export function mount() {}\n" }]
    }.freeze

    def test_an_item_with_a_module_under_community_pins_the_directory_once
      write_fixture("mesh-island", MODULE_ITEM)
      importmap = File.join(destination_root, "config/importmap.rb")
      FileUtils.mkdir_p(File.dirname(importmap))
      File.write(importmap, %(pin "application"\n))

      run_generator %w[./items/mesh-island.json]
      run_generator %w[./items/mesh-island.json]

      assert_file "app/javascript/community/islands/mesh.js", /mount/
      assert_equal 1, File.read(importmap).scan(%(pin_all_from "app/javascript/community", under: "community")).size
    end

    def test_an_item_without_a_community_module_leaves_the_importmap_alone
      prepare_remote_fixtures
      importmap = File.join(destination_root, "config/importmap.rb")
      FileUtils.mkdir_p(File.dirname(importmap))
      File.write(importmap, %(pin "application"\n))

      run_generator %w[./items/fancy-widget.json]

      assert_equal %(pin "application"\n), File.read(importmap)
    end

    def test_an_item_without_a_controller_leaves_the_controllers_manifest_alone
      prepare_remote_fixtures
      run_generator %w[./items/fancy-widget.json]

      assert_no_file "config/controllers_manifest.json"
    end
    PORT = {
      "name" => "phone-mockup", "type" => "registry:component",
      "registryDependencies" => %w[button frame-helper],
      "meta" => { "community" => true,
                  "source" => { "registry" => "@acme", "item" => "iphone", "url" => "https://acme.dev/r/iphone",
                                "repository" => "https://github.com/acme/ui", "license" => "MIT",
                                "copyright" => "Copyright (c) 2025 Acme",
                                "notice" => "MIT License\n\nPermission is hereby granted" } },
      "files" => [{ "path" => "app/components/community/phone_mockup/component.rb",
                    "content" => "class Community::PhoneMockup::Component < Poetry::Core::Component\nend\n" }]
    }.freeze

    FRAME = { "name" => "frame-helper", "type" => "registry:lib", "meta" => { "community" => true },
              "files" => [{ "path" => "app/helpers/community/frame_helper.rb",
                            "content" => "module Community::FrameHelper\nend\n" }] }.freeze

    def prepare_community(manifest = {})
      write_fixture("phone-mockup", PORT)
      write_fixture("frame-helper", FRAME)
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(File.join(destination_root, "config/poetry_components.yml"),
                 YAML.dump({ "community" => "./items/{name}.json" }.merge(manifest)))
    end

    def test_an_at_poetry_name_the_gems_do_not_ship_is_a_community_item
      prepare_community
      output = run_generator %w[@poetry/phone-mockup]

      assert_file "app/components/community/phone_mockup/component.rb"
      assert_file "app/helpers/community/frame_helper.rb", /FrameHelper/
      assert_no_file "app/components/poetry/ui/button/component.rb"
      assert_match(/phone-mockup: a community item, reviewed and checked in CI, not audited/, output)
      assert_match(%r{adapted from @acme/iphone \(MIT\)}, output)
    end

    def test_an_at_poetry_name_the_gems_ship_stays_local
      prepare_community
      run_generator %w[@poetry/badge]

      assert_file "app/components/poetry/ui/badge/component.rb"
    end

    def test_a_ports_origin_lands_in_the_manifest_and_the_notices_once
      prepare_community("registries" => { "@acme" => "https://acme.dev/r/{name}.json" })
      run_generator %w[@poetry/phone-mockup]
      run_generator %w[@poetry/phone-mockup]

      assert_file "config/poetry_components.yml" do |manifest|
        entry = YAML.safe_load(manifest).dig("components", "phone-mockup")

        assert_equal "@poetry/phone-mockup", entry["source"]
        assert entry["community"]
        assert_equal "https://github.com/acme/ui", entry.dig("origin", "repository")
        assert_nil entry.dig("origin", "notice"), "the license text lives in the notices, not the manifest"
      end
      assert_file "THIRD_PARTY_NOTICES.md" do |notices|
        assert_equal 1, notices.scan("## phone-mockup").size
        assert_match(%r{Adapted from @acme/iphone \(https://acme.dev/r/iphone\), https://github.com/acme/ui\.}, notices)
        assert_match(/License: MIT\. Copyright \(c\) 2025 Acme/, notices)
        assert_match(/Permission is hereby granted/, notices)
        refute_match(/frame-helper/, notices, "an original community item credits no origin")
      end
    end

    def test_an_unknown_bare_name_points_at_the_community_address
      error = assert_raises(ArgumentError) { run_generator %w[phone-mockup] }

      assert_match(%r{add it as @poetry/phone-mockup}, error.message)
    end
  end
end
