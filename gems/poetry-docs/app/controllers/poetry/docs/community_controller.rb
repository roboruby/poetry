module Poetry
  module Docs
    # The Community pages: the index (/community, a catalog page) and a
    # page per item (/community/components/:name), both read from the community
    # registry's index. The item pages sit outside the catalog - the items
    # are a host's configuration, and the catalog, the sidebar and the
    # committed search index are the same on every host. Where the host
    # names the address of the registry's saved demos, an item's page
    # runs its demo in a frame.
    class CommunityController < ApplicationController
      include MarkdownMirror

      # The Community section is a place of its own, outside the docs: its
      # pages wear its layout, with the search and the filters where the
      # docs have their nav.
      layout "poetry/docs/community"

      def index
        @entry = entry
        @browse = CommunityBrowse.new(CommunityRegistry.items, params)
      end

      def show
        @item = item
        @demo_url = demo_url(@item)
      end

      private

      def markdown_mirror
        case action_name
        when "index" then DocsMarkdown.community(entry, CommunityRegistry.items)
        when "show" then DocsMarkdown.community_item(item, demo_url: demo_url(item))
        end
      end

      def entry
        DocsCatalog.docs.find { |candidate| candidate.slug == "community" }
      end

      # Where the item's demo runs, for an item with a screenshot: the
      # frame stands in the screenshot's box, and the screenshot stays
      # when the demo does not answer.
      def demo_url(item)
        CommunityRegistry.demo_url(item.name, apart_from: request.base_url) if item.screenshot
      end

      # An unknown name is a 404 through the concern's RoutingError contract.
      def item
        CommunityRegistry.find(params[:name]) ||
          raise(ActionController::RoutingError, "unknown community item #{params[:name]}")
      end
    end
  end
end
