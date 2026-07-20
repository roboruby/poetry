# frozen_string_literal: true

require_relative "dommy_helper"

module DommyTier
  # The REAL poetry_optimistic_form markup driven by the REAL
  # poetry--core--optimistic-form controller: submit-start clones
  # the prediction template(s) into the document (Turbo would process the
  # stream; dommy has no Turbo, so the cloned element itself is the
  # assertion), submit-end appends the authoritative refresh ONLY when the
  # server rejected, and a burst of submits cannot stack duplicate clones.
  class OptimisticFormBehaviorTest < TestCase
    FORM = <<~ERB
      <%= poetry_optimistic_form(url: "/favorites", method: :post, attribute_name: :favorite, value: true) do |form| %>
        <%= form.optimistic_template "fav-icon", "starred" %>
        <%= form.button "Save" %>
      <% end %>
    ERB

    def render_form
      html = ApplicationController.renderer.render(inline: FORM, layout: false)
      render_in_dommy(%(<div id="page">#{html}<span id="fav-icon">plain</span></div>))
    end

    def submit_event(harness, name, success: nil)
      detail = success.nil? ? "{}" : "{ success: #{success} }"
      harness.evaluate(<<~JS)
        (() => {
          const form = document.querySelector("form");
          const event = new CustomEvent("#{name}", { bubbles: true, detail: #{detail} });
          form.dispatchEvent(event);
          return document.querySelectorAll("body > turbo-stream").length;
        })()
      JS
    end

    def test_submit_start_paints_the_prediction_and_throttles_bursts
      harness = render_form

      cloned = submit_event(harness, "turbo:submit-start")

      assert_equal 1, cloned, "the template's stream is cloned into the document"
      stream = harness.evaluate(<<~JS)
        (() => {
          const stream = document.querySelector("body > turbo-stream");
          // A template's payload lives in .content (innerHTML on the live
          // element is empty by the template contract).
          const payload = stream.querySelector("template");
          const text = payload.content ? payload.content.textContent : payload.textContent;
          return [stream.getAttribute("action"), stream.getAttribute("target"), text];
        })()
      JS

      assert_equal %w[update fav-icon starred], stream

      burst = submit_event(harness, "turbo:submit-start")

      assert_equal 1, burst, "a rapid resubmit inside the throttle window cannot stack clones"
      assert_no_js_errors(harness)
    end

    def test_submit_end_reconciles_only_on_failure
      harness = render_form

      after_success = submit_event(harness, "turbo:submit-end", success: true)

      assert_equal 0, after_success, "success trusts the optimistic paint - no refresh"

      submit_event(harness, "turbo:submit-end", success: false)
      refreshes = harness.evaluate(
        %(document.querySelectorAll('turbo-stream[action="refresh"]').length)
      )

      assert_equal 1, refreshes, "a rejected submission appends the authoritative refresh"
      assert_no_js_errors(harness)
    end
  end
end
