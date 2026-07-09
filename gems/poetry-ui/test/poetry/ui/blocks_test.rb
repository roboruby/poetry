# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The Blocks v1 gates: every shipped block is held to a stricter
    # standard than consumer templates - ZERO check findings (not just zero
    # errors) with the full production catalog, a clean render through the
    # app, and a registry entry whose metadata stays source-derived.
    class BlocksTest < Minitest::Test
      def templates
        Dir.glob(Poetry::Ui.root.join(Poetry::Ui::BLOCKS_DIR, "*.html.erb").to_s)
      end

      def registry_blocks
        @registry_blocks ||= YAML.safe_load_file(
          Poetry::Ui.root.join(Poetry::Core::Registry::RELATIVE_PATH)
        ).fetch("blocks")
      end

      def test_the_shipped_blocks_roster
        assert_equal %w[app-shell data-index destructive-panel page-header section-card top-nav],
                     registry_blocks.keys.sort
      end

      def test_every_block_lints_clean_with_the_full_production_catalog
        catalog = Poetry::Core::Check::Catalog.from_registry(
          Poetry::Ui.root,
          helpers: ComponentsHelper.public_instance_methods(false).grep(/\Apoetry_/),
          icon_names: Poetry::Core::Icons.set.names
        )
        findings = templates.to_h do |path|
          [File.basename(path), Poetry::Core::Check.lint(File.read(path), catalog: catalog)]
        end
        dirty = findings.reject { |_path, list| list.empty? }

        assert_empty dirty.transform_values { |list| list.map { |f| "#{f.rule}:#{f.line}" } },
                     "blocks are held to zero findings, warnings included"
      end

      def test_every_block_renders_through_the_app
        templates.each do |path|
          html = BlocksController.render(inline: File.read(path), layout: nil)

          assert_operator html.bytesize, :>, 500, "#{File.basename(path)} rendered suspiciously little"
        end
      end

      def test_registry_metadata_is_source_derived_and_templates_exist
        registry_blocks.each do |name, entry|
          template = Poetry::Ui.root.join(entry.fetch("template"))

          assert_predicate template, :exist?, "#{name}: template path must resolve"
          assert_match(/\A<%#\s*poetry:block title="#{Regexp.escape(entry["title"])}"/,
                       template.read, "#{name}: title comes from the template header")
          assert_operator entry.fetch("components").size, :>=, 2,
                          "#{name}: a block composes components - a near-empty list means the fold broke"
        end
      end

      # W4's outcome, locked: every block renders DesignLint-clean (the
      # app_shell h1->h3 lesson - source lint cannot see Card internals,
      # so blocks are held at the rendered tier).
      def test_every_block_renders_design_lint_clean
        templates.each do |path|
          html = BlocksController.render(inline: File.read(path), layout: nil)
          findings = Poetry::Core::DesignLint.lint(html)

          assert_empty findings.map(&:rule), "#{File.basename(path)} must render DesignLint-clean"
        end
      end

      # The mixed-status-weight fixture (lead): the v1.1 table arm
      # mixed a solid destructive pill into a soft status column - the rule
      # exists because this shipped past every other gate.
      def test_the_v11_table_arm_is_the_mixed_status_fixture
        html = BlocksController.render(
          inline: Poetry::Ui.root.join("eval/results/2026-07-09-v11/generated/table/poetry.html.erb").read,
          layout: nil
        )
        rules = Poetry::Core::DesignLint.lint(html).map(&:rule)

        assert_includes rules, "mixed-status-weight"
      end

      def test_the_app_shell_block_consumes_the_returned_sidebar_wrapper_marker
        source = Poetry::Ui.root.join(Poetry::Ui::BLOCKS_DIR, "app_shell.html.erb").read

        assert_includes source, "group-has-data-[collapsible=icon]/sidebar-wrapper:",
                        "the marker returned WITH its consumer ('s condition)"
        assert_includes Poetry::Ui::Sidebar::Style.css(:wrapper), "group/sidebar-wrapper"
      end

      def test_served_llms_text_carries_the_blocks_catalog
        # The controller's own construction (the shared-builder rule): the
        # served index must carry the blocks section, not just the committed
        # registry file.
        index = LlmsController.new.send(:llms_text).index

        assert_includes index, "## Blocks"
        assert_includes index, "(`data-index`)"
      end
    end
  end
end
