# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    class RegistryItemsTest < Minitest::Test
      # Real components: core's own registry over its own source tree.
      def core_items(dependencies: {})
        registry = Registry.new(components: [Poetry::Core::X::Component, Poetry::Core::Generic::Component])
        RegistryItems.new(registry: YAML.safe_load(registry.to_yaml), root: Poetry::Core.root,
                          gem_name: "poetry-core", gem_version: Poetry::Core::VERSION,
                          dependencies: dependencies)
      end

      def test_component_items_match_the_shadcn_item_schema
        item = core_items.item("x")

        assert_equal RegistryItems::ITEM_SCHEMA, item["$schema"]
        assert_equal "x", item["name"]
        assert_equal "registry:component", item["type"]
        assert_equal "X", item["title"]
        assert_equal "poetry-core", item.dig("meta", "gem")
        assert_equal "runtime-gem", item.dig("meta", "provided")
        assert_equal "Poetry::Core::X::Component", item.dig("meta", "class_name")
        # The part contract rides meta - /r consumers see the
        # DOM-verified styling surface without fetching source.
        assert_equal "icon", item.dig("meta", "parts", 0, "name")
      end

      def test_component_files_carry_real_source_with_mirrored_targets
        file = core_items.item("x")["files"].find { |entry| entry["path"].end_with?("component.rb") }

        assert_equal "app/components/poetry/core/x/component.rb", file["path"]
        assert_equal file["path"], file["target"]
        assert_equal Poetry::Core.root.join(file["path"]).read, file["content"]
      end

      def test_curated_dependencies_emit_as_kebab_registry_dependencies
        item = core_items(dependencies: { "x" => %w[generic] }).item("x")

        assert_equal %w[generic], item["registryDependencies"]
        assert_empty core_items.item("generic")["registryDependencies"]
      end

      def test_names_are_sorted_and_collision_checked
        assert_equal %w[generic x], core_items.names
      end

      def test_summaries_strip_content_but_keep_paths_and_targets
        summary = core_items.summaries.find { |entry| entry["name"] == "x" }

        refute_empty summary["files"]
        summary["files"].each do |file|
          refute file.key?("content")
          assert file["path"]
          assert file["target"]
        end
      end

      def test_block_items_strip_the_header_and_target_app_views_blocks
        Dir.mktmpdir do |root|
          template = "lib/generators/poetry/block/templates/hero_strip.html.erb"
          FileUtils.mkdir_p(File.join(root, File.dirname(template)))
          File.write(File.join(root, template),
                     %(<%# poetry:block title="Hero strip" description="A hero." %>\n<h1>Hero</h1>\n))
          registry = { "components" => {},
                       "blocks" => { "hero-strip" => {
                         "title" => "Hero strip", "description" => "A hero.",
                         "components" => %w[button app_shell], "template" => template,
                         "keywords" => %w[hero landing]
                       } } }
          items = RegistryItems.new(registry: registry, root: root, gem_name: "poetry-ui",
                                    gem_version: "0.0.0")
          item = items.item("hero-strip")

          assert_equal "registry:block", item["type"]
          assert_equal "<h1>Hero</h1>\n", item.dig("files", 0, "content"), "poetry:block header stripped"
          assert_equal "app/views/blocks/_hero_strip.html.erb", item.dig("files", 0, "target")
          assert_equal %w[button app-shell], item["registryDependencies"]
          assert_equal %w[hero landing], item.dig("meta", "keywords")
          assert_equal "copy-in", item.dig("meta", "provided")
        end
      end

      def test_nested_component_files_stay_with_their_own_item
        Dir.mktmpdir do |root|
          FileUtils.mkdir_p(File.join(root, "app/components/acme/box/lid"))
          File.write(File.join(root, "app/components/acme/box/component.rb"), "# box\n")
          File.write(File.join(root, "app/components/acme/box/lid/component.rb"), "# lid\n")
          registry = { "components" => {
            "acme/box" => { "class_name" => "Acme::Box::Component", "identifier" => "acme--box" },
            "acme/box/lid" => { "class_name" => "Acme::Box::Lid::Component", "identifier" => "acme--box--lid" }
          } }
          items = RegistryItems.new(registry: registry, root: root, gem_name: "acme",
                                    gem_version: "0.0.0")

          assert_equal(["app/components/acme/box/component.rb"],
                       items.item("box")["files"].map { |file| file["path"] })
          assert_equal(["app/components/acme/box/lid/component.rb"],
                       items.item("box-lid")["files"].map { |file| file["path"] })
        end
      end

      def test_sibling_file_nested_components_split_by_leaf_prefix
        Dir.mktmpdir do |root|
          FileUtils.mkdir_p(File.join(root, "app/components/acme/box"))
          File.write(File.join(root, "app/components/acme/box/component.rb"), "# box\n")
          File.write(File.join(root, "app/components/acme/box/lid_component.rb"), "# lid\n")
          File.write(File.join(root, "app/components/acme/box/lid_preview.rb"), "# lid preview\n")
          registry = { "components" => {
            "acme/box" => { "class_name" => "Acme::Box::Component", "identifier" => "acme--box" },
            "acme/box/lid" => { "class_name" => "Acme::Box::Lid::Component", "identifier" => "acme--box--lid" }
          } }
          items = RegistryItems.new(registry: registry, root: root, gem_name: "acme",
                                    gem_version: "0.0.0")

          assert_equal(["app/components/acme/box/component.rb"],
                       items.item("box")["files"].map { |file| file["path"] },
                       "the parent excludes leaf-prefixed files")
          assert_equal(["app/components/acme/box/lid_component.rb", "app/components/acme/box/lid_preview.rb"],
                       items.item("box-lid")["files"].map { |file| file["path"] },
                       "the command/dialog convention: sibling files, leaf-prefixed")
        end
      end
    end
  end
end
