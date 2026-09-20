# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The gem's own item projection: real facts
    # against the committed registry + source tree, so the docs site's
    # /r/*.json surface can never drift from what the gem ships.
    class RegistryItemsTest < Minitest::Test
      def items
        @items ||= Poetry::Ui.registry_items
      end

      def test_every_component_and_block_projects_to_one_kebab_item
        assert_includes items.names, "button"
        assert_includes items.names, "command-dialog", "nested component paths flatten to kebab"
        assert_includes items.names, "app-shell", "blocks are items too"
        assert_equal items.names, items.names.uniq.sort
      end

      def test_the_button_item_carries_its_real_source
        item = items.item("button")

        assert_equal "registry:component", item["type"]
        %w[component.rb style.rb component.html.erb preview.rb].each do |file|
          entry = item["files"].find { |candidate| candidate["path"].end_with?(file) }

          assert entry, "button item must carry #{file}"
          assert_equal Poetry::Ui.root.join(entry["path"]).read, entry["content"]
        end
        assert_equal %w[icon], item["registryDependencies"],
                     "the emitter and the add generator share ONE dependency map"
        assert_equal "poetry-ui", item.dig("meta", "gem")
      end

      def test_the_app_shell_block_item_targets_app_views_blocks
        item = items.item("app-shell")

        assert_equal "registry:block", item["type"]
        assert_equal "app/views/blocks/_app_shell.html.erb", item.dig("files", 0, "target")
        refute_match(/poetry:block/, item.dig("files", 0, "content"), "header stripped")
        assert_includes item["registryDependencies"], "sidebar"
        assert_equal "copy-in", item.dig("meta", "provided")
      end

      def test_the_dependency_map_is_single_sourced
        assert_same Poetry::Ui::COMPONENT_DEPENDENCIES, Poetry::AddGenerator::DEPENDENCIES
      end

      def test_command_dialog_owns_its_sibling_files_and_command_excludes_them
        dialog_paths = items.item("command-dialog")["files"].map { |file| file["path"] }

        assert_includes dialog_paths, "app/components/poetry/ui/command/dialog_component.rb"
        items.item("command")["files"].each do |file|
          refute_match(%r{/dialog_}, file["path"], "the parent item must not absorb the nested component")
        end
      end
    end
  end
end
