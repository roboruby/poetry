# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Sheet
      class ComponentTest < ViewComponent::TestCase
        SLIDE = { top: "slide-in-from-top", right: "slide-in-from-right",
                  bottom: "slide-in-from-bottom", left: "slide-in-from-left" }.freeze
        EDGE_BORDER = { top: "border-b", right: "border-l", bottom: "border-t", left: "border-r" }.freeze

        # Attribute assertions go through Nokogiri, never [^>]* regexes
        # across class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_sheet(**options, &config)
          render_inline(Component.new(**options).tap do |sheet|
            sheet.with_trigger(variant: :outline) { "Open" }
            sheet.with_title { "Filters" }
            config&.call(sheet)
          end.with_content("Body")).to_html
        end

        def sheet_dialog(html)
          doc(html).css('dialog[data-slot="sheet-content"]').first
        end

        def test_the_sheet_is_the_dialog_machinery_reskinned
          html = render_sheet
          root = doc(html).css('[data-slot="sheet"]').first
          dialog = sheet_dialog(html)

          # W5b commit 1: the Sheet's OWN controller (the dialog machinery
          # SUBCLASSED for the presence-hold close) - the
          # platform trap (showModal focus trap / Esc / top layer / focus
          # return) plus the controller's backdrop + scroll-lock wiring.
          assert_equal "sheet", root["data-component"]
          assert_equal "poetry--core--sheet", root["data-controller"]
          assert_equal "true", root["data-poetry--core--sheet-dismissible-value"]
          assert_equal "dialog", dialog["data-poetry--core--sheet-target"]
          assert_equal "cancel->poetry--core--sheet#close click->poetry--core--sheet#backdropClose",
                       dialog["data-action"]
          assert_equal "", dialog["data-closed"]
          assert_nil dialog["data-open"]
          assert_includes dialog["class"], "cn-sheet-content" # surface + backdrop tint ride the theme rule
          assert_match(/<button[^>]*data-action="poetry--core--sheet#open"/, html)
        end

        def test_every_side_stamps_data_side_and_its_slide_classes
          Component::SIDES.each do |side|
            dialog = sheet_dialog(render_sheet(side: side))

            assert_equal side.to_s, dialog["data-side"]
            # Slides + edge borders ride the per-side theme rule.
            assert_includes dialog["class"], "cn-sheet-side-#{side}"
            (Component::SIDES - [side]).each do |other|
              refute_includes dialog["class"], "cn-sheet-side-#{other}",
                              "side #{side} must not carry #{other}'s side class"
            end
          end
        end

        def test_side_defaults_to_right
          dialog = sheet_dialog(render_sheet)

          assert_equal "right", dialog["data-side"]
          assert_includes dialog["class"], "cn-sheet-side-right"
        end

        def test_closed_sheet_stays_hidden_under_ua_styles
          dialog = sheet_dialog(render_sheet)

          # open:flex, never bare flex: a bare display class defeats the
          # UA's dialog:not([open]) display:none (the Dialog's 2026-07-01
          # browser-pass lesson, inherited).
          assert_includes dialog["class"], "open:flex"
          refute_match(/(?<![:\w-])flex(?![\w-])/, dialog["class"],
                       "no unconditional display class on the <dialog>")
        end

        def test_title_is_required
          error = assert_raises(ArgumentError) do
            render_inline(Component.new.tap { |s| s.with_trigger { "Open" } }.with_content("x"))
          end

          assert_match(/with_title/, error.message)
        end

        def test_aria_labelledby_wires_sheet_scoped_ids
          html = render_sheet { |s| s.with_description { "Why" } }
          dialog = sheet_dialog(html)

          assert_match(/\Apoetry-sheet-\h{16}-title\z/, dialog["aria-labelledby"])
          assert_equal dialog["aria-labelledby"], doc(html).css('[data-slot="sheet-title"]').first["id"]
          assert_equal dialog["aria-describedby"], doc(html).css('[data-slot="sheet-description"]').first["id"]
        end

        def test_close_button_is_default_and_removable
          html = render_sheet
          close = doc(html).css('[data-slot="sheet-close"]').first

          assert close, "the icon-only close ships by default (showCloseButton parity)"
          assert_equal "Close", close["aria-label"]
          assert_equal "poetry--core--sheet#close", close["data-action"]

          refute_predicate doc(render_sheet(show_close_button: false)).css('[data-slot="sheet-close"]'), :any?
        end

        def test_the_root_wrapper_never_wears_the_side_chrome
          html = render_sheet(side: :right)
          root = doc(html).css('[data-slot="sheet"]').first

          # Same leak as the Drawer's direction chrome: the side branch
          # belongs to the <dialog>; on the wrapper the theme's ml-auto/
          # w-3/4/border-l would misplace it in the host's flow.
          assert_empty (root["class"] || "").split.grep(/cn-sheet-side/),
                       "side chrome leaked onto the non-visual root"
          assert_includes doc(html).css("dialog").first["class"].split, "cn-sheet-side-right"
        end

        def test_dismissible_false_flows_to_the_inherited_controller_value
          root = doc(render_sheet(dismissible: false)).css('[data-slot="sheet"]').first

          assert_equal "false", root["data-poetry--core--sheet-dismissible-value"]
        end

        def test_footer_pins_to_the_edge
          html = render_sheet do |sheet|
            sheet.with_footer { "Actions" }
          end
          footer = doc(html).css('[data-slot="sheet-footer"]').first

          assert_includes footer["class"], "mt-auto"
        end
      end
    end
  end
end
