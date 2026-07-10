# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    # LlmsText's blocks surface (Blocks v1): the index teaches the
    # block-first decision hierarchy, the full text inlines every block's
    # source (metadata header stripped), and registries without blocks emit
    # neither section. Component emission is covered end-to-end by the
    # registry gates; these tests pin the new blocks logic with a minimal
    # registry double.
    class LlmsTextTest < Minitest::Test
      FakeRegistry = Data.define(:entries, :blocks, :source_root)

      TEMPLATE = <<~ERB
        <%# poetry:block title="Data index" description="A records screen." %>
        <section>
          <%= poetry_badge { "Fulfilled" } %>
        </section>
      ERB

      def with_registry
        Dir.mktmpdir("llms-blocks") do |dir|
          Pathname(dir).join("blocks").mkpath
          Pathname(dir).join("blocks/data_index.html.erb").write(TEMPLATE)
          yield FakeRegistry.new(
            entries: {},
            blocks: { "data-index" => { "title" => "Data index", "description" => "A records screen.",
                                        "components" => %w[badge], "template" => "blocks/data_index.html.erb" } },
            source_root: Pathname(dir)
          )
        end
      end

      def test_index_lists_blocks_with_the_decision_hierarchy
        with_registry do |registry|
          index = LlmsText.new(registry: registry).index

          assert_includes index, "## Blocks"
          assert_includes index, "Start a screen from a vetted block"
          assert_includes index, "- Data index (`data-index`): A records screen. [composes: badge]"
        end
      end

      def test_full_inlines_block_source_without_the_metadata_header
        with_registry do |registry|
          full = LlmsText.new(registry: registry).full

          assert_includes full, "## Block: Data index (`data-index`)"
          assert_includes full, "bin/rails g poetry:block data-index"
          assert_includes full, %(<%= poetry_badge { "Fulfilled" } %>)
          refute_includes full, "poetry:block title=", "the source metadata header is stripped"
        end
      end

      def test_registries_without_blocks_emit_no_blocks_sections
        registry = FakeRegistry.new(entries: {}, blocks: nil, source_root: Pathname("."))
        text = LlmsText.new(registry: registry)

        refute_includes text.index, "## Blocks"
        refute_includes text.full, "## Block:"
      end

      # The crash classes, stated in the contract text: a component
      # that requires content says so up front; a slot states its yieldless
      # setters, its closed keyword set, and its required content block.
      def test_full_states_the_block_seam_contracts
        entry = {
          "class_name" => "Poetry::Ui::Carousel::Component", "bem_block" => "poetry-ui-carousel",
          "identifier" => "poetry--ui--carousel",
          "styles" => [], "options" => [],
          "requires_content" => "the initials fallback",
          "slots" => [
            { "name" => "items", "many" => true,
              "yieldless" => ["item"],
              "setter_kwargs" => { "item" => ["classes"] },
              "required_content" => { "item" => "the slide" } }
          ]
        }
        registry = FakeRegistry.new(entries: { "poetry/ui/carousel" => entry }, blocks: nil,
                                    source_root: Pathname("."))
        full = LlmsText.new(registry: registry).full

        assert_includes full, "Content block REQUIRED (the initials fallback) - a blockless call raises."
        assert_includes full, "with_item yields NOTHING to the block - no |param|, write content directly"
        assert_includes full, "with_item keywords: classes: ONLY"
        assert_includes full, "with_item REQUIRES a content block (the slide)"
      end
    end
  end
end
