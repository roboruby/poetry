# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module AlertDialog
      class ComponentTest < ViewComponent::TestCase
        # Attribute assertions go through Nokogiri, never [^>]* regexes
        # across class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def build(**, &config)
          Component.new(**).tap do |dialog|
            dialog.with_trigger(variant: :destructive) { "Delete" }
            dialog.with_title { "Are you absolutely sure?" }
            dialog.with_description { "This cannot be undone." }
            dialog.with_cancel { "Cancel" }
            dialog.with_action(variant: :destructive) { "Delete" }
            config&.call(dialog)
          end.with_content("")
        end

        def render_alert(**, &)
          render_inline(build(**, &)).to_html
        end

        def alert(html)
          doc(html).css('dialog[data-slot="alert-dialog-content"]').first
        end

        def test_renders_role_alertdialog_on_the_native_dialog
          html = render_alert
          dialog = alert(html)

          assert_equal "alertdialog", dialog["role"]
          assert_equal "", dialog["data-closed"]
          assert_nil dialog["data-open"]
          assert_equal "dialog", dialog["data-poetry--core--dialog-target"]
          assert_includes dialog["class"], "cn-alert-dialog-content"
          assert_includes dialog["class"], "open:grid"
        end

        def test_dismissible_is_always_false_and_esc_stays_wired
          root = doc(render_alert).css('[data-slot="alert-dialog"]').first
          dialog = alert(render_alert)

          # The posture IS the component: the value is rendered by the
          # component (no dismissible option exists), so backdropClose
          # no-ops while cancel->close (Esc) still runs - the controller's
          # deliberate asymmetry (Radix-exact); this test guards it.
          assert_equal "alert_dialog", root["data-component"]
          assert_equal "poetry--core--dialog", root["data-controller"]
          assert_equal "false", root["data-poetry--core--dialog-dismissible-value"]
          assert_equal "cancel->poetry--core--dialog#close click->poetry--core--dialog#backdropClose",
                       dialog["data-action"]
        end

        def test_missing_title_raises
          error = assert_raises(ArgumentError) do
            render_inline(Component.new.tap do |d|
              d.with_description { "Why" }
              d.with_cancel { "Cancel" }
              d.with_action { "Go" }
            end.with_content(""))
          end

          assert_match(/with_title/, error.message)
        end

        def test_missing_description_raises
          error = assert_raises(ArgumentError) do
            render_inline(Component.new.tap do |d|
              d.with_title { "Sure?" }
              d.with_cancel { "Cancel" }
              d.with_action { "Go" }
            end.with_content(""))
          end

          assert_match(/with_description/, error.message)
        end

        def test_missing_action_or_cancel_raises
          error = assert_raises(ArgumentError) do
            render_inline(Component.new.tap do |d|
              d.with_title { "Sure?" }
              d.with_description { "Why" }
              d.with_cancel { "Cancel" }
            end.with_content(""))
          end

          assert_match(/with_action/, error.message)

          error = assert_raises(ArgumentError) do
            render_inline(Component.new.tap do |d|
              d.with_title { "Sure?" }
              d.with_description { "Why" }
              d.with_action { "Go" }
            end.with_content(""))
          end

          assert_match(/with_cancel/, error.message)
        end

        def test_cancel_is_an_outline_button_with_initial_focus
          cancel = doc(render_alert).css('[data-slot="alert-dialog-cancel"]').first

          assert_equal "button", cancel.name
          assert_equal "outline", cancel["data-variant"]
          assert cancel.key?("autofocus"),
                 "cancel takes initial focus (APG: the least-destructive action; the native " \
                 "<dialog> focus heuristic honors autofocus)"
        end

        def test_action_is_a_typed_button_slot_with_source_defaults
          destructive = doc(render_alert).css('[data-slot="alert-dialog-action"]').first

          assert_equal "destructive", destructive["data-variant"]

          plain = doc(render_alert { |d| d.with_action { "Continue" } })
                  .css('[data-slot="alert-dialog-action"]').first

          assert_equal "default", plain["data-variant"]
          refute plain.key?("autofocus"), "only cancel autofocuses"
        end

        def test_no_x_close_button_renders
          html = render_alert
          fragment = doc(html)

          # The choice must be explicit - no icon-only close in the corner,
          # deliberate. The dismiss lives in the footer (cancel/action), so
          # the header carries no button and nothing is a dedicated close.
          header = fragment.css('[data-slot="alert-dialog-header"]').first

          assert_predicate header.css("button"), :empty?
          assert_predicate fragment.css('[data-slot="alert-dialog-close"]'), :empty?
          assert_predicate fragment.css('[aria-label="Close"]'), :empty?
        end

        def test_cancel_and_action_close_the_shared_dialog
          fragment = doc(render_alert)
          cancel = fragment.css('[data-slot="alert-dialog-cancel"]').first
          action = fragment.css('[data-slot="alert-dialog-action"]').first

          # Both footer choices dismiss the native <dialog> through the shared
          # controller (Radix AlertDialogCancel / AlertDialogAction both
          # close). Without this the modal is unclosable except by Esc.
          assert_equal "poetry--core--dialog#close", cancel["data-action"]
          assert_equal "poetry--core--dialog#close", action["data-action"]
        end

        def test_aria_labelledby_and_describedby_are_always_wired
          html = render_alert
          dialog = alert(html)

          assert_match(/\Apoetry-alert-dialog-\h{16}-title\z/, dialog["aria-labelledby"])
          assert_equal dialog["aria-labelledby"], doc(html).css('[data-slot="alert-dialog-title"]').first["id"]
          assert_equal dialog["aria-describedby"],
                       doc(html).css('[data-slot="alert-dialog-description"]').first["id"]
        end

        def test_size_stamps_data_size_and_the_compact_footer
          default_html = render_alert
          sm_html = render_alert(size: :sm)

          assert_equal "default", alert(default_html)["data-size"]
          assert_equal "sm", alert(sm_html)["data-size"]

          default_footer = doc(default_html).css('[data-slot="alert-dialog-footer"]').first
          sm_footer = doc(sm_html).css('[data-slot="alert-dialog-footer"]').first

          refute_includes default_footer["class"], "grid-cols-2"
          assert_includes sm_footer["class"], "grid-cols-2"

          # default size goes left from sm; sm size stays centered (source).
          assert_includes doc(default_html).css('[data-slot="alert-dialog-header"]').first["class"], "sm:text-left"
          refute_includes doc(sm_html).css('[data-slot="alert-dialog-header"]').first["class"], "sm:text-left"
        end

        def test_media_well_emits_its_conditional_classes_server_side
          plain = doc(render_alert)

          assert_predicate plain.css('[data-slot="alert-dialog-media"]'), :empty?
          refute_includes plain.css('[data-slot="alert-dialog-header"]').first["class"], "grid-rows-[auto_auto_1fr]"

          html = render_alert do |d|
            d.with_media { "!" }
          end
          fragment = doc(html)
          media = fragment.css('[data-slot="alert-dialog-media"]').first

          assert_includes media["class"], "cn-alert-dialog-media"
          assert_includes media["class"], "sm:row-span-2"
          assert_includes fragment.css('[data-slot="alert-dialog-header"]').first["class"], "grid-rows-[auto_auto_1fr]"
          assert_includes fragment.css('[data-slot="alert-dialog-title"]').first["class"], "sm:col-start-2"
        end

        def test_trigger_is_a_poetry_button_wired_to_open
          trigger = doc(render_alert).css("button").find { |b| b["data-action"] == "poetry--core--dialog#open" }

          assert trigger, "the trigger opens through the shared controller"
          assert_equal "destructive", trigger["data-variant"]
        end
      end
    end
  end
end
