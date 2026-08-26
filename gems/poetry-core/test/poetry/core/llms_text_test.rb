# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    # LlmsText's blocks surface: the index teaches the
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

      def test_full_lists_the_declared_tools
        with_registry do |registry|
          entry = { "class_name" => "Poetry::Ui::Tabs::Component", "styles" => [], "options" => [], "slots" => [],
                    "tools" => [{ "name" => "set_value", "description" => "Activate the tab whose value matches.",
                                  "inputSchema" => { "type" => "object",
                                                     "properties" => { "value" => { "type" => "string" } },
                                                     "required" => ["value"] },
                                  "annotations" => { "readOnlyHint" => false, "untrustedContentHint" => false },
                                  "executes" => "poetry--core--tabs#setValue" }] }
          full = LlmsText.new(registry: FakeRegistry.new(entries: { "poetry/ui/tabs" => entry },
                                                         blocks: registry.blocks,
                                                         source_root: registry.source_root)).full

          assert_includes full, "- tool set_value (mutating; params: value (string, required))"
          assert_includes full, "dispatches poetry--core--tabs#setValue"
        end
      end

      def test_index_lists_blocks_with_the_decision_hierarchy
        with_registry do |registry|
          index = LlmsText.new(registry: registry).index

          assert_includes index, "## Blocks"
          assert_includes index, "Blocks are the DEFAULT starting point, not a fallback"
          assert_includes index, "route every\nbrief through the MCP `compose` tool first"
          assert_includes index, "- Data index (`data-index`): A records screen. [composes: badge]"
        end
      end

      # The block back-reference: the component section points UP at
      # the blocks composing it, so wherever an agent enters the catalog
      # the arrow to the vetted composition is in view.
      def test_component_sections_carry_the_block_back_reference
        with_registry do |registry|
          entry = { "class_name" => "Poetry::Ui::Badge::Component", "bem_block" => "poetry-ui-badge",
                    "styles" => [], "options" => [], "slots" => [] }
          full = LlmsText.new(registry: FakeRegistry.new(entries: { "poetry/ui/badge" => entry },
                                                         blocks: registry.blocks,
                                                         source_root: registry.source_root)).full

          assert_includes full, "In blocks: `data-index` - for a screen, start from the block"
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

      # The setter-seam crash classes, stated in the contract text: a component
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

      # The styling contract, stated where agents read: every part
      # with its state attributes (enum values inline) and var seams.
      def test_full_states_the_part_contract
        entry = {
          "class_name" => "Poetry::Ui::Dialog::Component", "bem_block" => "poetry-ui-dialog",
          "identifier" => "poetry--ui--dialog",
          "styles" => [], "options" => [], "slots" => [],
          "parts" => [
            { "name" => "dialog-content", "description" => "The panel",
              "states" => [
                { "attr" => "data-open", "condition" => "panel is open" },
                { "attr" => "data-side", "condition" => "resolved side", "values" => %w[top bottom] }
              ],
              "vars" => [{ "name" => "--transform-origin", "description" => "popper origin" }] }
          ]
        }
        registry = FakeRegistry.new(entries: { "poetry/ui/dialog" => entry }, blocks: nil,
                                    source_root: Pathname("."))
        full = LlmsText.new(registry: registry).full

        assert_includes full,
                        "- PART `dialog-content` - The panel | states: data-open (panel is open); " \
                        "data-side=top|bottom (resolved side) | vars: --transform-origin (popper origin)"
      end

      # The menu crash class, stated in the contract text: a
      # required slot speaks at the component level AND at the nested
      # builder seam where the menu crash actually lived.
      def test_full_states_the_required_slot_contracts
        entry = {
          "class_name" => "Poetry::Ui::Menubar::Component", "bem_block" => "poetry-ui-menubar",
          "identifier" => "poetry--ui--menubar",
          "styles" => [], "options" => [],
          "required_slots" => { "menu" => "at least one menu" },
          "slots" => [
            { "name" => "menus", "many" => true,
              "builders" => { "menu" => {
                "required_slots" => { "trigger" => "the top-level menu button" }, "slots" => []
              } } }
          ]
        }
        registry = FakeRegistry.new(entries: { "poetry/ui/menubar" => entry }, blocks: nil,
                                    source_root: Pathname("."))
        full = LlmsText.new(registry: registry).full

        assert_includes full, "Slot REQUIRED: with_menu (at least one menu) - a call without it raises."
        assert_includes full,
                        "each with_menu REQUIRES with_trigger inside its block (the top-level menu button)"
      end

      # The any-of contracts, stated in the contract text: the
      # disjunction reads as one line naming every alternative.
      def test_full_states_the_any_of_contracts
        entry = {
          "class_name" => "Poetry::Ui::Button::Component", "bem_block" => "poetry-ui-button",
          "identifier" => "poetry--ui--button",
          "styles" => [], "options" => [], "slots" => [],
          "requires_any" => [
            { "hint" => "nothing visible renders without one", "content" => true,
              "slots" => %w[leading trailing], "options" => %w[loading] }
          ]
        }
        registry = FakeRegistry.new(entries: { "poetry/ui/button" => entry }, blocks: nil,
                                    source_root: Pathname("."))
        full = LlmsText.new(registry: registry).full

        assert_includes full, "REQUIRED - one of a content block / with_leading / with_trailing / " \
                              "loading: (nothing visible renders without one); a call satisfying " \
                              "none raises."
      end
    end
  end
end
