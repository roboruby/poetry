# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Popover
      class ComponentTest < ViewComponent::TestCase
        # Attribute assertions go through Nokogiri, never [^>]* regexes
        # across class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_popover(**, &block)
          block ||= lambda { |popover|
            popover.with_trigger(variant: :outline) { "Open popover" }
            popover.with_title { "Dimensions" }
          }
          render_inline(Component.new(**), &block).to_html
        end

        def test_root_hosts_both_controllers_on_one_attributes_instance
          html = render_popover
          root = doc(html).css('[data-slot="popover"]').first
          trigger = doc(html).css('[data-slot="popover-trigger"]').first

          assert_equal "popover", root["data-component"]
          # ONE shared Attributes instance: token-concatenated, not overwritten.
          assert_equal "poetry--core--popover poetry--core--popper", root["data-controller"]
          assert_equal "false", root["data-poetry--core--popover-open-value"]
          # Radix Popover parity: modal defaults FALSE (the menu family's contrast).
          assert_equal "false", root["data-poetry--core--popover-modal-value"]
          assert_equal "bottom", root["data-poetry--core--popper-side-value"]
          assert_equal "center", root["data-poetry--core--popper-align-value"]
          assert_equal "4", root["data-poetry--core--popper-side-offset-value"]
          assert_equal "0", root["data-poetry--core--popper-align-offset-value"]
          assert_equal "true", root["data-poetry--core--popper-avoid-collisions-value"]
          # With no anchor part the trigger anchors by id selector.
          assert_equal "##{trigger["id"]}", root["data-poetry--core--popper-anchor-value"]
        end

        def test_trigger_is_an_aria_wired_dialog_button
          html = render_popover
          trigger = doc(html).css('button[data-slot="popover-trigger"]').first
          content = doc(html).css('[data-slot="popover-content"]').first

          assert_equal "dialog", trigger["aria-haspopup"]
          assert_equal "false", trigger["aria-expanded"]
          # aria-controls always rendered (Radix: open-only) - the static
          # server id is the controller's structural-resolution seam.
          assert_equal content["id"], trigger["aria-controls"]
          refute trigger.key?("data-popup-open"), "closed trigger carries NO state attribute (absence IS the state)"
          assert_equal "click->poetry--core--popover#toggle", trigger["data-action"]
          # No custom keydown map: native button Enter/Space arrive as click
          # (the deliberate contrast with the menu trigger).
          refute_includes trigger["data-action"], "keydown"
          # The composed poetry Button keeps its own identity (demo parity).
          assert_equal "button", trigger["data-component"]
        end

        def test_content_is_a_closed_named_dialog_with_no_static_layer_controllers
          html = render_popover
          content = doc(html).css('[data-slot="popover-content"]').first
          title = doc(html).css('[data-slot="popover-title"]').first

          assert_equal "dialog", content["role"]
          assert_equal "-1", content["tabindex"]
          assert content.key?("data-closed"), "mounted-closed popup carries bare data-closed"
          refute content.key?("data-open")
          assert content.key?("hidden"), "closed content is hidden (truthful server render)"
          assert_equal "content", content["data-poetry--core--popper-target"]
          assert_equal "bottom", content["data-side"]
          assert_equal "center", content["data-align"]
          # POETRY ADDITION over new-york-v4's unwired divs: the title part
          # names the dialog.
          assert_equal title["id"], content["aria-labelledby"]
          # The layer controllers (focus-scope/dismissable) are token-
          # ACTIVATED by the popover controller on open - a static trap on
          # hidden content would steal focus at page load.
          assert_nil content["data-controller"]
        end

        def test_header_title_and_description_parts_render_wired
          html = render_popover do |popover|
            popover.with_trigger { "Open" }
            popover.with_title { "Dimensions" }
            popover.with_description { "Set the dimensions for the layer." }
          end
          fragment = doc(html)
          header = fragment.css('[data-slot="popover-header"]').first
          title = fragment.css('[data-slot="popover-title"]').first
          description = fragment.css('p[data-slot="popover-description"]').first
          content = fragment.css('[data-slot="popover-content"]').first

          assert_includes header["class"], "flex-col"
          assert_equal "Dimensions", title.text
          assert_includes title["class"], "cn-popover-title"
          assert_equal "Set the dimensions for the layer.", description.text
          assert_includes description["class"], "cn-popover-description"
          assert_equal title["id"], content["aria-labelledby"]
          assert_equal description["id"], content["aria-describedby"]
          # No ARIA roles on the parts - name/description are wired by id.
          assert_nil title["role"]
        end

        def test_label_names_the_dialog_when_no_title_part
          html = render_popover(label: "Quick settings") do |popover|
            popover.with_trigger { "Open" }
            "Body"
          end
          content = doc(html).css('[data-slot="popover-content"]').first

          assert_equal "Quick settings", content["aria-label"]
          assert_nil content["aria-labelledby"]
          refute_predicate doc(html).css('[data-slot="popover-header"]'), :any?
        end

        def test_nameless_dialog_trips_the_lint_warning
          warnings = capture_rails_warnings do
            render_popover { |popover| popover.with_trigger { "Open" } }
          end

          assert_equal 1, warnings.size
          assert_includes warnings.first, "no accessible name"
        end

        def test_named_dialogs_do_not_warn
          warnings = capture_rails_warnings { render_popover }

          assert_empty warnings
        end

        def test_open_state_is_server_rendered
          html = render_popover(open: true)
          content = doc(html).css('[data-slot="popover-content"]').first
          trigger = doc(html).css('[data-slot="popover-trigger"]').first

          assert content.key?("data-open"), "open popup carries bare data-open"
          refute content.key?("data-closed")
          refute content.key?("hidden")
          assert_equal "true", trigger["aria-expanded"]
          assert trigger.key?("data-popup-open"), "open trigger carries bare data-popup-open"
        end

        def test_anchor_part_takes_the_popper_anchor_target
          html = render_popover do |popover|
            popover.with_trigger { "Open" }
            popover.with_anchor { "Anchored here" }
            popover.with_title { "Anchored" }
          end
          fragment = doc(html)
          root = fragment.css('[data-slot="popover"]').first
          anchor = fragment.css('[data-slot="popover-anchor"]').first

          assert_equal "anchor", anchor["data-poetry--core--popper-target"]
          # The trigger-selector fallback is dropped: the anchor part IS the
          # popper reference (Radix PopoverAnchor semantics).
          assert_nil root["data-poetry--core--popper-anchor-value"]
          refute_predicate fragment.css('[data-slot="popover-trigger"][data-poetry--core--popper-target]'), :any?
        end

        def test_modal_true_forwards_to_the_controller_value
          root = doc(render_popover(modal: true)).css('[data-slot="popover"]').first

          assert_equal "true", root["data-poetry--core--popover-modal-value"]
        end

        def test_trigger_is_required
          assert_raises(ArgumentError) do
            render_inline(Component.new) { |popover| popover.with_title { "Nope" } }
          end
        end

        def test_source_exact_classes_land_on_the_content
          html = render_popover

          assert_includes html, "origin-(--radix-popover-content-transform-origin)"
          assert_includes html, "w-72"
          # Panel chrome + the animate/slide chains ride the theme rule.
          assert_includes html, "cn-popover-content"
          assert_includes html, "outline-hidden"
        end

        def test_content_class_overrides_the_source_width_via_merge
          content = doc(render_popover(content_class: "w-80")).css('[data-slot="popover-content"]').first

          # Demo parity: w-80 replaces the source w-72 (tailwind_merge -
          # caller classes win on conflicts, never append).
          assert_includes content["class"], "w-80"
          refute_includes content["class"], "w-72"
        end
      end
    end
  end
end
