# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Toast
      class ComponentTest < ViewComponent::TestCase
        # Attribute assertions go through Nokogiri, never [^>]* regexes
        # across class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_toast(**, &block)
          block ||= lambda { |toast|
            toast.with_title { "Changes saved" }
            toast.with_description { "Your profile has been updated." }
          }
          render_inline(Component.new(**), &block).to_html
        end

        def test_the_item_is_a_muted_status_li_that_never_self_announces
          html = render_toast
          toast = doc(html).css('li[data-slot="toast"]').first

          assert toast, "a toast is an <li> (list semantics are the a11y contract - no polymorphic tag:)"
          assert_equal "toast", toast["data-component"]
          assert_equal "status", toast["role"]
          # aria-live=off ON PURPOSE: the announce SINGLETON does the
          # talking exactly once (the Radix duplication insight).
          assert_equal "off", toast["aria-live"]
          assert_equal "true", toast["aria-atomic"]
          assert_equal "0", toast["tabindex"]
          assert_equal "", toast["data-open"]
          assert_nil toast["data-closed"]
          assert_equal "default", toast["data-variant"]
        end

        def test_timer_wiring_pauses_on_hover_and_focus
          toast = doc(render_toast).css('[data-slot="toast"]').first

          assert_equal "poetry--core--toast", toast["data-controller"]
          assert_equal "5000", toast["data-poetry--core--toast-duration-value"]
          assert_equal "polite", toast["data-poetry--core--toast-politeness-value"]
          # APG/WCAG 2.2.1 Timing Adjustable: hover AND focus-within hold
          # the timer (window blur / tab-hidden holds are controller-wired).
          %w[
            mouseenter->poetry--core--toast#pause
            focusin->poetry--core--toast#pause
            mouseleave->poetry--core--toast#resume
            focusout->poetry--core--toast#resume
          ].each { |action| assert_includes toast["data-action"], action }
        end

        def test_destructive_derives_assertive_politeness_and_its_icon
          html = render_toast(variant: :destructive)
          toast = doc(html).css('[data-slot="toast"]').first
          icon = toast.css('[data-slot="toast-icon"]').first

          assert_equal "destructive", toast["data-variant"]
          assert_equal "assertive", toast["data-poetry--core--toast-politeness-value"]
          assert_equal "true", icon["aria-hidden"]
          assert_predicate icon.css("svg"), :any?, "the octagon-x variant icon ships built in"
        end

        def test_default_variant_ships_no_icon_and_polite_announcement
          toast = doc(render_toast).css('[data-slot="toast"]').first

          refute_predicate toast.css('[data-slot="toast-icon"]'), :any?
          assert_equal "polite", toast["data-poetry--core--toast-politeness-value"]
        end

        def test_politeness_is_overridable
          toast = doc(render_toast(politeness: :assertive)).css('[data-slot="toast"]').first

          assert_equal "assertive", toast["data-poetry--core--toast-politeness-value"]
        end

        def test_title_and_description_parts_render
          html = render_toast

          assert_equal "Changes saved", doc(html).css('[data-slot="toast-title"]').first.text
          assert_equal "Your profile has been updated.",
                       doc(html).css('[data-slot="toast-description"]').first.text
        end

        def test_title_is_required
          error = assert_raises(ArgumentError) do
            render_inline(Component.new) { |toast| toast.with_description { "no message" } }
          end

          assert_match(/with_title/, error.message)
        end

        def test_action_bearing_toasts_default_to_persistent
          html = render_toast do |toast|
            toast.with_title { "Message deleted" }
            toast.with_action { "Undo" }
          end
          toast = doc(html).css('[data-slot="toast"]').first
          action = doc(html).css('button[data-slot="toast-action"]').first

          # A missable undo is a bug: duration nil + action -> 0 (persistent).
          assert_equal "0", toast["data-poetry--core--toast-duration-value"]
          assert_equal "action", action["data-poetry--core--toast-target"]
          assert_includes action["data-action"], "click->poetry--core--toast#dismiss"
          # The composed poetry Button keeps its own identity.
          assert_equal "button", action["data-component"]
        end

        def test_explicit_duration_wins_over_the_action_default
          html = render_toast(duration: 10_000) do |toast|
            toast.with_title { "Message deleted" }
            toast.with_action { "Undo" }
          end

          assert_equal "10000",
                       doc(html).css('[data-slot="toast"]').first["data-poetry--core--toast-duration-value"]
        end

        def test_close_button_is_default_and_removable
          html = render_toast
          close = doc(html).css('[data-slot="toast-close"]').first

          assert close, "the icon-only close ships by default (closable: true)"
          assert_equal "Close", close["aria-label"]
          assert_equal "close", close["data-poetry--core--toast-target"]
          assert_includes close["data-action"], "click->poetry--core--toast#dismiss"

          refute_predicate doc(render_toast(closable: false)).css('[data-slot="toast-close"]'), :any?
        end

        def test_variant_classes_ride_the_popover_token_surface
          html = render_toast(variant: :destructive)
          toast = doc(html).css('[data-slot="toast"]').first

          # The popover token surface + the corner-aware slide chains ride
          # .cn-toast; the destructive tinting rides its variant rule.
          assert_includes toast["class"], "cn-toast"
          assert_includes toast["class"], "cn-toast-variant-destructive"
        end
      end
    end
  end
end
