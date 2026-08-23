# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module HoverCard
      class ComponentTest < ViewComponent::TestCase
        # Attribute assertions go through Nokogiri, never [^>]* regexes
        # across class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_card(**, &block)
          block ||= lambda { |card|
            card.with_trigger(href: "https://github.com/nextjs") { "@nextjs" }
            "The React Framework."
          }
          render_inline(Component.new(**), &block).to_html
        end

        def test_root_hosts_both_controllers_on_one_attributes_instance
          html = render_card
          root = doc(html).css('[data-slot="hover-card"]').first

          assert_equal "hover_card", root["data-component"]
          # ONE shared Attributes instance: token-concatenated, not overwritten.
          assert_equal "poetry--core--hover-card poetry--core--popper", root["data-controller"]
          assert_equal "false", root["data-poetry--core--hover-card-open-value"]
          # Base UI PreviewCard defaults: openDelay 600 / closeDelay 300
          # (the closeDelay IS the grace window - no polygon at these delays).
          assert_equal "600", root["data-poetry--core--hover-card-open-delay-value"]
          assert_equal "300", root["data-poetry--core--hover-card-close-delay-value"]
          assert_equal "bottom", root["data-poetry--core--popper-side-value"]
          assert_equal "center", root["data-poetry--core--popper-align-value"]
          assert_equal "4", root["data-poetry--core--popper-side-offset-value"]
          assert_equal "true", root["data-poetry--core--popper-avoid-collisions-value"]
        end

        def test_trigger_is_a_real_link_with_no_aria_surface
          html = render_card
          trigger = doc(html).css('a[data-slot="hover-card-trigger"]').first

          assert trigger, "the trigger IS an <a> - the no-JS fallback, touch path, and keyboard path at once"
          assert_equal "https://github.com/nextjs", trigger["href"]
          refute trigger.key?("data-popup-open"), "closed trigger carries NO state attribute (absence IS the state)"
          assert_equal "anchor", trigger["data-poetry--core--popper-target"]
          %w[
            pointerenter->poetry--core--hover-card#pointerEnter
            pointerleave->poetry--core--hover-card#pointerLeave
            focus->poetry--core--hover-card#focusOpen
            blur->poetry--core--hover-card#blurClose
            touchstart->poetry--core--hover-card#touchGuard
          ].each { |action| assert_includes trigger["data-action"], action }
          # NO aria anywhere (Radix-exact, deliberate): advertising a
          # keyboard-unreachable surface to AT is worse than silence.
          assert_nil trigger["aria-haspopup"]
          assert_nil trigger["aria-expanded"]
          assert_nil trigger["aria-controls"]
          assert_nil trigger["aria-describedby"]
        end

        def test_variant_trigger_renders_through_button_but_stays_a_real_link
          html = render_card do |card|
            card.with_trigger(href: "https://github.com/nextjs", variant: :outline) { "Left" }
            "This hover card appears on the left side of the trigger."
          end
          trigger = doc(html).css('a[data-slot="hover-card-trigger"]').first

          assert trigger, "the button-styled trigger is STILL an <a> (Button's href-implies-anchor)"
          assert_equal "https://github.com/nextjs", trigger["href"]
          assert_includes trigger["class"], "cn-button-variant-outline"
          # The full hover-card wiring rides along untouched.
          assert_equal "anchor", trigger["data-poetry--core--popper-target"]
          assert_includes trigger["data-action"], "pointerenter->poetry--core--hover-card#pointerEnter"
          assert_nil trigger["aria-haspopup"]
        end

        def test_content_is_a_role_less_hidden_panel_with_the_structural_id_pair
          html = render_card
          trigger = doc(html).css('[data-slot="hover-card-trigger"]').first
          content = doc(html).css('[data-slot="hover-card-content"]').first

          # Role-less div (Radix-exact): the card is not an AT surface.
          assert_nil content["role"]
          assert content.key?("data-closed"), "mounted-closed popup carries bare data-closed"
          refute content.key?("data-open")
          assert content.key?("hidden")
          assert_equal "content", content["data-poetry--core--popper-target"]
          # The id pair is STRUCTURAL resolution only - never aria-wired.
          assert_match(/\Apoetry-hover-card-\h{16}-trigger\z/, trigger["id"])
          assert_equal trigger["id"].sub(/-trigger\z/, "-content"), content["id"]
          # The dismissable layer is token-activated while open, never
          # server-rendered.
          assert_nil content["data-controller"]
        end

        def test_pinned_open_is_server_rendered
          html = render_card(open: true)
          trigger = doc(html).css('[data-slot="hover-card-trigger"]').first
          content = doc(html).css('[data-slot="hover-card-content"]').first

          assert trigger.key?("data-popup-open"), "open trigger carries bare data-popup-open"
          assert content.key?("data-open"), "open popup carries bare data-open"
          refute content.key?("data-closed")
          refute content.key?("hidden")
        end

        def test_delay_overrides_forward_to_the_controller_values
          root = doc(render_card(open_delay: 300, close_delay: 150)).css('[data-slot="hover-card"]').first

          assert_equal "300", root["data-poetry--core--hover-card-open-delay-value"]
          assert_equal "150", root["data-poetry--core--hover-card-close-delay-value"]
        end

        def test_missing_href_trips_the_reachable_elsewhere_lint_warning
          warnings = capture_rails_warnings do
            render_card { |card| card.with_trigger { "@nextjs" } }
          end

          assert_equal 1, warnings.size
          assert_includes warnings.first, "reachable-elsewhere"
        end

        def test_a_real_href_does_not_warn
          warnings = capture_rails_warnings { render_card }

          assert_empty warnings
        end

        def test_trigger_is_required
          assert_raises(ArgumentError) do
            render_inline(Component.new) { "Preview body" }
          end
        end

        def test_source_exact_classes_land_on_the_content
          content = doc(render_card).css('[data-slot="hover-card-content"]').first
          classes = content["class"].split

          assert_includes classes, "origin-(--transform-origin)"
          # Panel chrome + width + the animate/slide chains ride the theme
          # rule (width is theme-side - mira/rhea widen it).
          assert_includes classes, "cn-hover-card-content"
          assert_includes classes, "outline-hidden"
          refute_includes classes, "w-64"
        end

        def test_content_class_overrides_the_theme_width_from_the_utilities_layer
          content = doc(render_card(content_class: "w-80")).css('[data-slot="hover-card-content"]').first

          # Demo parity: caller w-80 rides the utilities layer, which beats
          # the theme rule's width in every fragment (layer order).
          assert_includes content["class"], "w-80"
        end
      end
    end
  end
end
