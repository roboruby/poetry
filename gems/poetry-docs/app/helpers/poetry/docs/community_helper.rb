# frozen_string_literal: true

module Poetry
  module Docs
    # The Community section's tabs, for its layout and its pages: which
    # there are, and which one a page is under.
    module CommunityHelper
      # The section's tabs, each a title and a path: the host's where it
      # names them (it serves the section's pages itself), and otherwise
      # the engine's one, Components at its own index.
      # @return [Array<Array(String, String)>]
      def community_tabs
        Poetry::Docs.config.community_tabs.presence || [ [ "Components", poetry_docs.community_path ] ]
      end

      # The tab a page is under: the one whose path the page's own begins
      # with, the longest where several do; nil where none does.
      # @param path [String] the page's path
      # @return [Array(String, String), nil]
      def community_tab(path = request.path)
        community_tabs.select { |_, tab| path == tab || path.start_with?("#{tab}/") }.max_by { |_, tab| tab.size }
      end
    end
  end
end
