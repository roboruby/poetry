# frozen_string_literal: true

module Poetry
  module Docs
    # The poetry-motion effect pages, /motion/<slug>: the shared gallery page
    # (installation, examples, styling, wiring, behaviors) and its markdown
    # mirror, like the chart pages.
    class MotionController < ApplicationController
      include MarkdownMirror

      def show
        @entry = DocsCatalog.find("motion", params[:slug])
        raise ActionController::RoutingError, "unknown effect #{params[:slug]}" unless @entry

        @examples = helpers.docs_examples_for("motion", @entry.slug)
        render template: "poetry/docs/docs/page"
      end

      private

      def markdown_mirror
        entry = DocsCatalog.find("motion", params[:slug])
        raise ActionController::RoutingError, "unknown effect #{params[:slug]}" unless entry

        DocsMarkdown.example_page(entry)
      end
    end
  end
end
