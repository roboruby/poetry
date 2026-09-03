# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Dialog
      class ComponentTest < ViewComponent::TestCase
        def render_dialog(**, &config)
          render_inline(Component.new(**).tap do |dialog|
            dialog.with_trigger(variant: :outline) { "Open" }
            dialog.with_title { "Settings" }
            config&.call(dialog)
          end.with_content("Body")).to_html
        end

        def test_renders_a_native_dialog_on_the_platform_trap
          html = render_dialog

          assert_includes html, "<dialog"
          assert_includes html, 'data-controller="poetry--core--dialog"'
          assert_includes html, 'data-closed=""'
          assert_includes html, "cn-dialog-content" # panel chrome + backdrop tint ride the theme rule
          assert_includes html,
                          'data-action="cancel->poetry--core--dialog#close click->poetry--core--dialog#backdropClose"'
        end

        def test_closed_dialog_stays_hidden_under_ua_styles
          html = render_dialog

          # open:grid, never bare grid: a bare display class defeats the
          # UA's dialog:not([open]) display:none and shows the dialog
          # inline while closed.
          assert_includes html, "open:grid"
          refute_match(/class="[^"]*(?<![:\w-])grid[ "]/, html, "no unconditional display class on the <dialog>")
        end

        def test_trigger_is_a_poetry_button_wired_to_open
          html = render_dialog

          assert_match(/<button[^>]*data-action="poetry--core--dialog#open"[^>]*>/, html)
          assert_includes html, 'data-variant="outline"'
        end

        def test_aria_labelledby_always_wires_to_the_title
          html = render_dialog

          id = html[/aria-labelledby="([^"]+)"/, 1]

          assert id
          assert_includes html, %(<h2 id="#{id}")
        end

        def test_describedby_only_with_a_description
          refute_includes render_dialog, "aria-describedby"

          html = render_dialog { |d| d.with_description { "Why" } }
          id = html[/aria-describedby="([^"]+)"/, 1]

          assert id
          assert_includes html, %(<p id="#{id}")
        end

        def test_title_is_required
          error = assert_raises(ArgumentError) do
            render_inline(Component.new.tap { |d| d.with_trigger { "Open" } }.with_content("x"))
          end

          assert_match(/with_title/, error.message)
        end

        def test_close_button_is_icon_only_with_i18n_accessible_name
          html = render_dialog

          assert_includes html, 'aria-label="Close"'
          assert_includes html, 'data-action="poetry--core--dialog#close"'
        end

        def test_show_close_button_false_removes_the_corner_x
          html = render_dialog(show_close_button: false)

          refute_includes html, 'data-action="poetry--core--dialog#close"'
          refute_includes html, 'aria-label="Close"'
          # Esc still closes - the <dialog> cancel wiring is untouched.
          assert_includes html, "cancel->poetry--core--dialog#close"
        end

        def test_dismissible_false_flows_to_the_controller_value
          html = render_dialog(dismissible: false)

          assert_includes html, 'data-poetry--core--dialog-dismissible-value="false"'
        end

        def test_two_dialogs_never_share_label_ids
          first = render_dialog[/aria-labelledby="([^"]+)"/, 1]
          second = render_dialog[/aria-labelledby="([^"]+)"/, 1]

          refute_equal first, second
        end

        # The wiring blocks below build markup the way a view would.
        def tag = ActionController::Base.helpers.tag

        def test_wiring_block_composes_a_custom_trigger
          html = render_inline(Component.new) do |dialog|
            dialog.with_trigger(compose: true) do |wiring|
              tag.button("Open it", class: "custom-trigger", **wiring)
            end
            dialog.with_title { "Title" }
            "Body"
          end.to_html
          trigger = Nokogiri::HTML.fragment(html).css("button.custom-trigger").first

          assert trigger, "the block's markup renders as the trigger"
          assert_includes trigger["data-action"].to_s, "open"
        end
      end
    end
  end
end
