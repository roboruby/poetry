# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # N9 W1 display statics: Avatar, Breadcrumb, Progress, Item - pure
    # markup, so the contract is the semantics + the a11y hooks.
    class DisplayStaticsTest < ViewComponent::TestCase
      # -- Avatar ---------------------------------------------------------------

      def test_avatar_layers_the_fallback_under_the_image
        html = render_inline(Avatar::Component.new(src: "/matt.jpg", label: "Matt Solt")) { "MS" }
        root = html.css('[data-slot="avatar"]').first

        assert_equal "img", root["role"]
        assert_equal "Matt Solt", root["aria-label"], "the accessible name lives on the root"
        fallback = root.css('[data-slot="avatar-fallback"]').first

        assert_equal "MS", fallback.text
        img = root.css("img").first

        assert_equal "", img["alt"], "alt is empty so a FAILED load paints nothing over the initials"
        assert_includes img["class"], "absolute", "the image covers the fallback (server-native layering)"
      end

      def test_avatar_without_src_is_just_the_fallback
        html = render_inline(Avatar::Component.new(label: "Ada Lovelace", size: :sm)) { "AL" }

        assert_empty html.css("img")
        assert_equal "sm", html.css('[data-slot="avatar"]').first["data-size"]
      end

      def test_avatar_requires_its_accessible_name_and_fallback
        assert_raises(ArgumentError) { render_inline(Avatar::Component.new(src: "/x.jpg")) { "X" } }
        assert_raises(ArgumentError) { render_inline(Avatar::Component.new(label: "X")) }
      end

      def test_avatar_badge_is_decorative
        html = render_inline(Avatar::Component.new(label: "Grace Hopper (online)")) do |avatar|
          avatar.with_badge { "" }
          "GH"
        end

        assert_equal "true", html.css('[data-slot="avatar-badge"]').first["aria-hidden"]
      end

      # -- Breadcrumb -----------------------------------------------------------

      def test_breadcrumb_is_a_labelled_nav_with_a_current_page
        html = render_inline(Breadcrumb::Component.new) do |crumb|
          crumb.with_item("Home", href: "/")
          crumb.with_item("Components", href: "/components")
          crumb.with_item("Breadcrumb")
        end

        nav = html.css("nav").first

        assert_equal "breadcrumb", nav["aria-label"]
        assert_equal 2, nav.css('a[data-slot="breadcrumb-link"]').length
        current = nav.css('[aria-current="page"]').first

        assert_equal "Breadcrumb", current.text
        assert_equal 2, nav.css('[data-slot="breadcrumb-separator"]').length, "separators between items only"
        assert(nav.css('[data-slot="breadcrumb-separator"]').all? { |li| li["aria-hidden"] == "true" })
      end

      def test_breadcrumb_ellipsis_announces_more_outside_the_hidden_glyph
        html = render_inline(Breadcrumb::Component.new) do |crumb|
          crumb.with_item("Home", href: "/")
          crumb.with_ellipsis
          crumb.with_item("Current")
        end

        ellipsis = html.css('[data-slot="breadcrumb-ellipsis"]').first

        assert_equal "true", ellipsis["aria-hidden"]
        sr_only = html.css("li span.sr-only").first

        assert_equal "More", sr_only.text
        assert_not_equal ellipsis, sr_only.parent, "the sr-only text must NOT sit inside the aria-hidden span"
      end

      def test_breadcrumb_requires_items
        assert_raises(ArgumentError) { render_inline(Breadcrumb::Component.new) }
      end

      # -- Progress -------------------------------------------------------------

      def test_progress_announces_its_value_and_sizes_the_indicator
        html = render_inline(Progress::Component.new(value: 60, label: "Uploading photos"))
        root = html.css('[data-slot="progress"]').first

        assert_equal "progressbar", root["role"]
        assert_equal "60", root["aria-valuenow"]
        assert_equal "100", root["aria-valuemax"]
        assert_equal "Uploading photos", root["aria-label"]
        assert_includes root.css('[data-slot="progress-indicator"]').first["style"], "width: 60"
        assert_equal "60%", root.css('[data-slot="progress-value"]').first.text
      end

      def test_progress_scales_a_custom_max
        html = render_inline(Progress::Component.new(value: 3, max: 8, label: "Steps", show_value: false))

        assert_includes html.css('[data-slot="progress-indicator"]').first["style"], "width: 37.5"
        assert_empty html.css('[data-slot="progress-value"]')
      end

      def test_progress_requires_a_label
        assert_raises(ArgumentError) { render_inline(Progress::Component.new(value: 10)) }
      end

      # -- Item -----------------------------------------------------------------

      def test_item_composes_media_content_and_actions
        html = render_inline(Item::Component.new(variant: :outline, media_variant: :icon)) do |item|
          item.with_media { "✓" }
          item.with_title { "Verified" }
          item.with_description { "Your profile has been verified." }
          item.with_actions { "View" }
        end

        root = html.css('[data-slot="item"]').first

        assert_equal "outline", root["data-variant"]
        assert_equal "icon", root.css('[data-slot="item-media"]').first["data-variant"]
        assert_equal "Verified", root.css('[data-slot="item-title"]').first.text
        description = root.css('[data-slot="item-description"]').first

        assert_equal "p", description.name, "the description is a real paragraph"
        assert_predicate root.css('[data-slot="item-actions"]'), :any?
      end

      def test_item_renders_as_a_link_row_when_asked
        html = render_inline(Item::Component.new(tag: :a, href: "/setting")) do |item|
          item.with_title { "Settings" }
        end

        root = html.css('a[data-slot="item"]').first

        assert_equal "/setting", root["href"]
      end
    end
  end
end
