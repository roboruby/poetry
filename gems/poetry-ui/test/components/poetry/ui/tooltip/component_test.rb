# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Tooltip
      class ComponentTest < ViewComponent::TestCase
        # Attribute assertions go through Nokogiri, never [^>]* regexes
        # across class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_tooltip(**, &block)
          block ||= lambda { |tooltip|
            tooltip.with_trigger(variant: :outline) { "Hover" }
            "Add to library"
          }
          render_inline(Component.new(**), &block).to_html
        end

        def test_root_hosts_both_controllers_on_one_attributes_instance
          html = render_tooltip
          root = doc(html).css('[data-slot="tooltip"]').first

          assert_equal "tooltip", root["data-component"]
          # ONE shared Attributes instance: token-concatenated, not overwritten.
          assert_equal "poetry--core--tooltip poetry--core--popper", root["data-controller"]
          assert_equal "false", root["data-poetry--core--tooltip-open-value"]
          # Radix Tooltip placement defaults: side top (the trio's odd one
          # out), sideOffset 0 (the arrow supplies the gap).
          assert_equal "top", root["data-poetry--core--popper-side-value"]
          assert_equal "center", root["data-poetry--core--popper-align-value"]
          assert_equal "0", root["data-poetry--core--popper-side-offset-value"]
        end

        def test_provider_inherited_values_render_no_attribute_when_unset
          root = doc(render_tooltip).css('[data-slot="tooltip"]').first

          # The controller checks attribute PRESENCE to decide between the
          # per-tooltip override and the provider config - an unset option
          # must render nothing at all.
          assert_nil root["data-poetry--core--tooltip-delay-duration-value"]
          assert_nil root["data-poetry--core--tooltip-disable-hoverable-content-value"]

          overridden = doc(render_tooltip(delay_duration: 700, disable_hoverable_content: true))
                       .css('[data-slot="tooltip"]').first

          assert_equal "700", overridden["data-poetry--core--tooltip-delay-duration-value"]
          assert_equal "true", overridden["data-poetry--core--tooltip-disable-hoverable-content-value"]
        end

        def test_trigger_is_a_timing_wired_control_with_no_popup_aria
          html = render_tooltip
          trigger = doc(html).css('button[data-slot="tooltip-trigger"]').first

          refute trigger.key?("data-popup-open"), "closed trigger carries NO state attribute (absence IS the state)"
          assert_equal "anchor", trigger["data-poetry--core--popper-target"]
          %w[
            pointermove->poetry--core--tooltip#pointerMove
            pointerleave->poetry--core--tooltip#pointerLeave
            pointerdown->poetry--core--tooltip#pointerDown
            click->poetry--core--tooltip#clickClose
            focus->poetry--core--tooltip#focusOpen
            blur->poetry--core--tooltip#blurClose
          ].each { |action| assert_includes trigger["data-action"], action }
          # A tooltip DESCRIBES - it is not a popup the user operates
          # (APG-exact): no haspopup/expanded, and describedby only while
          # open (never on a closed server render).
          assert_nil trigger["aria-haspopup"]
          assert_nil trigger["aria-expanded"]
          assert_nil trigger["aria-describedby"]
          # The composed poetry Button keeps its own identity.
          assert_equal "button", trigger["data-component"]
        end

        def test_content_is_a_hidden_role_tooltip_with_the_stable_id_pair
          html = render_tooltip
          trigger = doc(html).css('[data-slot="tooltip-trigger"]').first
          content = doc(html).css('[data-slot="tooltip-content"]').first

          assert_equal "tooltip", content["role"]
          assert content.key?("data-closed"), "mounted-closed popup carries bare data-closed"
          refute content.key?("data-open")
          assert content.key?("hidden")
          assert_equal "content", content["data-poetry--core--popper-target"]
          # The id pair IS the controller's structural resolution seam
          # ("-trigger" -> "-content", portal-safe).
          assert_match(/\Apoetry-tooltip-\h{8}-trigger\z/, trigger["id"])
          assert_equal trigger["id"].sub(/-trigger\z/, "-content"), content["id"]
          # No layer controllers server-rendered: the dismissable is
          # token-activated while open (topmost-Esc correctness).
          assert_nil content["data-controller"]
        end

        def test_the_arrow_ships_built_in_as_the_popper_arrow_target
          html = render_tooltip
          arrow = doc(html).css('[data-slot="tooltip-arrow"]').first
          inner = arrow.css("span").first

          assert_equal "arrow", arrow["data-poetry--core--popper-target"]
          assert_equal "true", arrow["aria-hidden"]
          # The visual classes ride the INNER span (popper positions and
          # rotates the outer box) - source-exact from new-york-v4.
          assert_includes inner["class"], "rotate-45"
          assert_includes inner["class"], "translate-y-[calc(-50%_-_2px)]"
          assert_includes inner["class"], "bg-foreground"
        end

        def test_pinned_open_renders_data_open_and_describedby
          html = render_tooltip(open: true)
          trigger = doc(html).css('[data-slot="tooltip-trigger"]').first
          content = doc(html).css('[data-slot="tooltip-content"]').first

          # The Radix triple collapsed to the Base UI pair: a pinned tooltip
          # is bare data-open on the content + data-popup-open on the
          # trigger (data-instant is a runtime-only reason attribute).
          assert trigger.key?("data-popup-open"), "open trigger carries bare data-popup-open"
          assert content.key?("data-open"), "open popup carries bare data-open"
          refute content.key?("data-closed")
          refute content.key?("hidden")
          assert_equal content["id"], trigger["aria-describedby"]
        end

        def test_label_substitutes_the_announced_body_for_rich_content
          html = render_tooltip(label: "Command S saves") do |tooltip|
            tooltip.with_trigger { "Save" }
            "Saves <kbd>⌘S</kbd>".html_safe
          end
          content = doc(html).css('[data-slot="tooltip-content"]').first
          visual = content.css("span[aria-hidden]").first
          announced = content.css("span.sr-only").first

          # One content node, two layers: the rich children stay visual
          # (aria-hidden), the sr-only label carries the announcement.
          assert_predicate visual.css("kbd"), :any?
          assert_equal "Command S saves", announced.text
        end

        def test_source_exact_classes_include_the_ungated_animate_in
          content = doc(render_tooltip).css('[data-slot="tooltip-content"]').first
          classes = content["class"].split

          # The open animation is UNCONDITIONAL (source-exact) - only the
          # exit chain is data-closed-gated.
          assert_includes classes, "animate-in"
          assert_includes classes, "fade-in-0"
          assert_includes classes, "zoom-in-95"
          assert_includes classes, "bg-foreground"
          assert_includes classes, "text-background"
          assert_includes classes, "origin-(--radix-tooltip-content-transform-origin)"
          assert_includes classes, "data-closed:animate-out"
        end

        def test_content_class_merges_over_the_source_classes
          content = doc(render_tooltip(content_class: "max-w-xs")).css('[data-slot="tooltip-content"]').first

          assert_includes content["class"], "max-w-xs"
        end

        def test_trigger_is_required
          assert_raises(ArgumentError) do
            render_inline(Component.new) { "Just text" }
          end
        end
      end
    end
  end
end
