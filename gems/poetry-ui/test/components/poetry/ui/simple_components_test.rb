# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # M6a: Link, Badge, Card, Alert - contract tests.
    class SimpleComponentsTest < ViewComponent::TestCase
      # -- Link ---------------------------------------------------------------

      def test_link_renders_a_real_anchor_with_the_contract
        html = render_inline(Link::Component.new(href: "/pricing")) { "Pricing" }.to_html

        assert_includes html, 'href="/pricing"'
        assert_includes html, 'data-component="link"'
        assert_includes html, "hover:underline"
        refute_includes html, "aria-current"
      end

      def test_link_current_and_external
        html = render_inline(Link::Component.new(href: "/d", current: true, external: true)) { "D" }.to_html

        assert_includes html, 'aria-current="page"'
        assert_includes html, 'target="_blank"'
        assert_includes html, 'rel="noopener noreferrer"'
      end

      def test_link_underline_variants
        assert_includes render_inline(Link::Component.new(href: "/", underline: :always)) { "x" }.to_html,
                        %( underline)
        refute_includes render_inline(Link::Component.new(href: "/", underline: :none)) { "x" }.to_html,
                        "hover:underline"
      end

      # -- Badge --------------------------------------------------------------

      def test_badge_variants_render_on_semantic_tokens
        Badge::Component::VARIANTS.each do |variant|
          html = render_inline(Badge::Component.new(variant: variant)) { "New" }.to_html

          assert_includes html, %(data-variant="#{variant}")
        end

        destructive = render_inline(Badge::Component.new(variant: :destructive)) { "x" }.to_html

        assert_includes destructive, "dark:bg-destructive/60"
      end

      # -- Alert --------------------------------------------------------------

      def test_alert_default_is_polite_status
        html = render_inline(Alert::Component.new) do |alert|
          alert.with_title { "Heads up" }
          "Something happened."
        end.to_html

        assert_includes html, 'role="status"'
        assert_includes html, 'data-slot="alert-title"'
        assert_includes html, 'data-slot="alert-description"'
        assert_includes html, "font-medium tracking-tight" # the title element classes resolve
      end

      def test_alert_destructive_announces_assertively
        html = render_inline(Alert::Component.new(variant: :destructive)) { "Payment failed." }.to_html

        assert_includes html, 'role="alert"'
        assert_includes html, "text-destructive"
      end

      def test_alert_icon_slot_is_typed
        html = render_inline(Alert::Component.new) do |alert|
          alert.with_icon(name: :"triangle-alert")
          "Careful."
        end.to_html

        assert_includes html, 'data-component="icon"'
      end

      # -- Card ---------------------------------------------------------------

      def test_card_composes_via_data_slots
        html = render_inline(Card::Component.new) do |card|
          card.with_title { "Revenue" }
          card.with_description { "Last 30 days" }
          card.with_action { "···" }
          card.with_footer { "Updated hourly" }
          "$12,345"
        end.to_html

        %w[card card-header card-title card-description card-action card-content card-footer].each do |slot|
          assert_includes html, %(data-slot="#{slot}"), "missing #{slot}"
        end
        assert_includes html, "has-data-[slot=card-action]:grid-cols-[1fr_auto]"
      end

      def test_card_without_header_parts_renders_no_header
        html = render_inline(Card::Component.new) { "Body only" }.to_html

        refute_includes html, 'data-slot="card-header"'
        assert_includes html, 'data-slot="card-content"'
      end

      # -- Cross-cutting -------------------------------------------------------

      def test_all_four_are_in_the_registry_with_agent_rules
        entries = Poetry::Core::Registry.new(source_root: Poetry::Ui.root).entries

        %w[link badge card alert].each do |name|
          entry = entries.fetch("poetry/ui/#{name}")

          assert_predicate entry["agent_rules"], :any?, "#{name} must carry agent rules"
        end
      end

      def test_all_four_render_in_bem_mode
        Poetry::Core::Config.current.css_mode = :bem
        html = render_inline(Badge::Component.new(variant: :outline)) { "x" }.to_html

        assert_includes html, "poetry-ui-badge--variant-outline"
        refute_includes html, "rounded-md"
      ensure
        Poetry::Core::Config.current.css_mode = :tailwind
      end
    end
  end
end
