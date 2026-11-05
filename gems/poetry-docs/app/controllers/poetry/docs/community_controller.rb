module Poetry
  module Docs
    # The Community pages: the index (/community, a catalog page) and a
    # page per item (/community/:name), both read from the community
    # registry's index. The item pages sit outside the catalog - the items
    # are a host's configuration, and the catalog, the sidebar and the
    # committed search index are the same on every host.
    class CommunityController < ApplicationController
      include MarkdownMirror

      def index
        @entry = entry
        @items = CommunityRegistry.items
      end

      def show
        @item = item
      end

      private

      def markdown_mirror
        case action_name
        when "index" then DocsMarkdown.community(entry, CommunityRegistry.items)
        when "show" then DocsMarkdown.community_item(item)
        end
      end

      def entry
        DocsCatalog.docs.find { |candidate| candidate.slug == "community" }
      end

      # An unknown name is a 404 through the concern's RoutingError contract.
      def item
        CommunityRegistry.find(params[:name]) ||
          raise(ActionController::RoutingError, "unknown community item #{params[:name]}")
      end
    end
  end
end
