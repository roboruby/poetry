# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The deferred-region helper + its two slot adoptions. The
    # frame's runtime behavior (error stamp, retry) lives in poetry-core's
    # deferred.test.js; here we prove the server-rendered contract.
    class DeferredHelperTest < ActionDispatch::IntegrationTest
      def render_erb(erb)
        ApplicationController.renderer.render(inline: erb, layout: false)
      end

      def doc_for(erb)
        Nokogiri::HTML::DocumentFragment.parse(render_erb(erb))
      end

      def test_renders_a_lazy_frame_with_skeleton_placeholder_and_retryable_error_template
        html = render_erb(%(<%= poetry_deferred(src: "/activity") %>))
        doc = Nokogiri::HTML::DocumentFragment.parse(html)

        frame = doc.at_css("turbo-frame")

        assert_nil frame["src"], "src is armed at connect (the boot-race contract)"
        assert_equal "/activity", frame["data-poetry--core--deferred-src-value"]
        assert_equal "lazy", frame["loading"]
        assert_equal "poetry--core--deferred", frame["data-controller"]
        assert frame["id"].start_with?("poetry-deferred-"), "stable derived id"

        placeholder = doc.at_css('[data-poetry--core--deferred-target="placeholder"]')

        assert placeholder.at_css("[data-slot=skeleton]"), "default placeholder is a Skeleton"

        assert doc.at_css('template[data-poetry--core--deferred-target="error"]')
        assert_includes html, "This section failed to load."
        assert_includes html, "click-&gt;poetry--core--deferred#retry"
      end

      def test_block_overrides_the_placeholder_and_eager_sets_loading
        doc = doc_for(%(<%= poetry_deferred(src: "/a", loading: :eager) { "custom wait" } %>))

        assert_equal "eager", doc.at_css("turbo-frame")["loading"]
        placeholder = doc.at_css('[data-poetry--core--deferred-target="placeholder"]')

        assert_includes placeholder.text, "custom wait"
        assert_nil placeholder.at_css("[data-slot=skeleton]")
      end

      def test_tabs_panel_defers_via_the_frame
        doc = doc_for(<<~ERB)
          <%= poetry_tabs(label: "Sections") do |tabs| %>
            <% tabs.with_tab("Overview", value: "overview") do %>Static<% end %>
            <% tabs.with_tab("Activity", value: "activity", defer: "/activity") %>
          <% end %>
        ERB

        panels = doc.css("[data-slot=tabs-content]")

        assert_equal 2, panels.length
        frame = panels.last.at_css("turbo-frame[loading=lazy]")

        refute_nil frame, "deferred panel wraps a lazy frame"
        assert_equal "/activity", frame["data-poetry--core--deferred-src-value"]
      end

      def test_tabs_still_requires_panel_or_defer
        error = assert_raises ActionView::Template::Error do
          render_erb(<<~ERB)
            <%= poetry_tabs(label: "Sections") do |tabs| %>
              <% tabs.with_tab("Empty", value: "empty") %>
            <% end %>
          ERB
        end

        assert_match(/requires a panel block, defer:, or panel: false/, error.message)
      end

      def test_hover_card_defer_swaps_the_body_for_a_frame_with_block_as_placeholder
        doc = doc_for(<<~ERB)
          <%= poetry_hover_card(defer: "/preview") do |card| %>
            <% card.with_trigger(href: "/u/kate") { "@kate" } %>
            waiting…
          <% end %>
        ERB

        content = doc.at_css("[data-slot=hover-card-content]")
        frame = content.at_css("turbo-frame[loading=lazy]")

        refute_nil frame, "defer: renders the card body as a lazy frame"
        assert_equal "/preview", frame["data-poetry--core--deferred-src-value"]
        assert_includes frame.at_css('[data-poetry--core--deferred-target="placeholder"]').text, "waiting…"
      end
    end
  end
end
