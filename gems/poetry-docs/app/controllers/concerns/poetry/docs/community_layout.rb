# frozen_string_literal: true

module Poetry
  module Docs
    # The Community section's layout for a host application's own
    # controllers: a page the host serves in the section (a library
    # directory, a feed) wears the site's header and the section's tabs,
    # and where it has filters, a sidebar that holds them. The page puts
    # its filters in `content_for :community_sidebar`; a page with none is
    # drawn at full width. Like HostLayout, the layout reaches the engine's
    # routes through its mount proxy, so the host mounts the engine under
    # its default name, `poetry_docs`.
    #
    # @example A host page in the Community section
    #   class LibrariesController < ApplicationController
    #     include Poetry::Docs::CommunityLayout
    #
    #     def index
    #       @libraries = Library.search(params)
    #     end
    #   end
    module CommunityLayout
      extend ActiveSupport::Concern

      included do
        layout "poetry/docs/community"
        helper Poetry::Docs::PageMetaHelper, Poetry::Docs::DocsHelper
      end
    end
  end
end
