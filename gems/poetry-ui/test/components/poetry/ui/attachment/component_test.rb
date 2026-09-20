# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Attachment
      class ComponentTest < ViewComponent::TestCase
        def test_renders_the_contract_surface
          html = render_inline(Component.new) do |attachment|
            attachment.with_media { "F" }
            attachment.with_title { "report.pdf" }
            attachment.with_description { "1.2 MB" }
          end.to_html

          assert_includes html, 'data-component="attachment"'
          assert_includes html, 'data-upload-state="done"'
          assert_includes html, 'data-size="default"'
          assert_includes html, 'data-orientation="horizontal"'
          %w[attachment-media attachment-content attachment-title attachment-description].each do |slot|
            assert_includes html, %(data-slot="#{slot}"), slot
          end
        end

        def test_every_lifecycle_state_stamps_data_upload_state
          Component::STATES.each do |state|
            html = render_inline(Component.new(state: state)) { |a| a.with_title { "x" } }.to_html

            assert_includes html, %(data-upload-state="#{state}")
          end
        end

        def test_in_flight_and_error_states_announce_via_sr_only_status
          Component::ANNOUNCED_STATES.each do |state|
            html = render_inline(Component.new(state: state)) { |a| a.with_title { "x" } }.to_html

            assert_match(%r{<span[^>]*role="status"[^>]*class="sr-only"[^>]*>[^<]+</span>}, html, state.to_s)
          end
          done = render_inline(Component.new) { |a| a.with_title { "x" } }.to_html

          refute_includes done, 'role="status"', "settled states never announce"
        end

        def test_actions_are_icon_only_poetry_buttons_with_labels
          html = render_inline(Component.new) do |attachment|
            attachment.with_title { "x" }
            attachment.with_action(label: "Remove") { "×" }
          end.to_html

          assert_match(/<button[^>]*data-slot="attachment-action"/, html)
          assert_includes html, 'aria-label="Remove"'
          assert_includes html, 'data-size="icon-xs"'
        end

        def test_trigger_is_a_stretched_overlay_under_the_actions
          html = render_inline(Component.new) do |attachment|
            attachment.with_title { "x" }
            attachment.with_trigger { "open" }
          end.to_html

          assert_match(/<button[^>]*data-slot="attachment-trigger"[^>]*type="button"/, html)
          assert_includes html, "cn-attachment-trigger"
        end

        def test_media_image_variant_and_unknown_variant_guard
          html = render_inline(Component.new) do |attachment|
            attachment.with_media(variant: :image) { "img" }
            attachment.with_title { "x" }
          end.to_html

          assert_includes html, 'data-variant="image"'
          assert_raises(ArgumentError) do
            render_inline(Component.new) { |a| a.with_media(variant: :video) { "v" } }
          end
        end

        def test_shimmer_rides_the_dictionary
          assert_includes Style.css(:title), "group-data-[upload-state=uploading]/attachment:shimmer"
        end
      end
    end
  end
end
