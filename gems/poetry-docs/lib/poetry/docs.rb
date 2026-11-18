# frozen_string_literal: true

require "poetry/core"
require "poetry/ui"
require "poetry/lucide"
require "poetry/tabler"
require "poetry/hugeicons"
require "poetry/phosphor"
require "poetry/heroicons"
require "poetry/simple_icons"
require "poetry/solar"
require "poetry/blode"
require "poetry/charts"
require "poetry/motion"
require "poetry/island"
require "poetry/agent"
# The pagination guide pages one array through the three paginators the
# gemspec names, so the engine loads them rather than each host. Only their
# array and view parts: kaminari's core and Action View pieces and
# will_paginate's collection, never their Active Record extensions, so a
# host's own models keep the methods they have. will_paginate's view
# helpers load with the guide's link renderer.
require "pagy"
require "kaminari/core"
require "kaminari/actionview"
require "will_paginate/collection"
require "poetry/docs/version"
require "poetry/docs/engine"

module Poetry
  # The poetryui.com documentation as a mountable engine.
  module Docs
    # The gem's root directory: the views, the data and the skills the
    # engine serves resolve against it, never against the host's root.
    # @return [Pathname]
    def self.root = Engine.root

    # The Beehiiv publication the subscriptions endpoint posts to. A host
    # sets both in an initializer; absent, the endpoint answers 503.
    class Configuration
      # @return [String, nil] the Beehiiv API key
      attr_accessor :beehiiv_api_key
      # @return [String, nil] the Beehiiv publication id
      attr_accessor :beehiiv_publication_id
      # The community registry's build output: a directory holding one
      # <name>.json per item (what poetry:add installs), about/<name>.json
      # per item (what the pages show of it) and screenshots/. There is no
      # index. /r/<name>.json serves an item from it when the gems ship no
      # item of that name, and the Community pages list the items its
      # about/ folder holds; nil serves none.
      # @return [Pathname, String, nil]
      attr_accessor :community_registry
      # The address the community registry's saved demos are served from:
      # each item's demo as a static page, at /items/<name>/ on a host of
      # their own. An item's page then runs the demo in a frame, in its
      # screenshot's place. The address must be another origin than the
      # docs site's, because the frame lets the demo's scripts run; a demo
      # at the site's own origin is never framed. nil shows the screenshot.
      # @return [String, nil]
      attr_accessor :community_demos
      # Whether the site has a Community section, which puts Community in
      # the top nav: true or false as the host says, and otherwise whether
      # the community registry lists an item. A host that serves the
      # section's pages itself sets true.
      # @return [Boolean, nil]
      attr_writer :community_section
      # The Community section's tabs, each a title and a path, where a host
      # serves the section's pages itself and so names them all, in order
      # ([ [ "Components", "/community/components" ], [ "Libraries",
      # "/community/libraries" ] ]). Left unset, the section has the
      # engine's one tab: Components, at its own index. A component's page
      # leads back to the tab it is under.
      # @return [Array<Array(String, String)>]
      attr_writer :community_tabs
      # The host's own pages for the sitemap, beside the engine's: paths
      # ("/community/libraries/acme"), or anything that answers `call`
      # with them, asked on each request.
      # @return [Array<String>, #call, nil]
      attr_accessor :sitemap_paths
      # The stylesheet the layouts link. A host whose own pages wear the
      # docs layout builds the engine's stylesheet again with its view
      # folders added (rake poetry_docs:css:host) and names the result.
      # @return [String]
      attr_writer :stylesheet
      # The host's folders whose classes the host stylesheet carries, as
      # paths from the host's root ("app/views/community").
      # @return [Array<String>]
      attr_writer :stylesheet_sources

      def community_section?
        @community_section.nil? ? CommunityRegistry.items.any? : @community_section == true
      end

      def community_tabs = Array(@community_tabs)

      def stylesheet = @stylesheet || "poetry_docs"

      def stylesheet_sources = Array(@stylesheet_sources)

      # The host's sitemap paths, resolved.
      # @return [Array<String>]
      def host_sitemap_paths
        Array(sitemap_paths.respond_to?(:call) ? sitemap_paths.call : sitemap_paths).map(&:to_s)
      end
    end

    # @return [Configuration]
    def self.config = @config ||= Configuration.new

    # @yield [Configuration]
    def self.configure
      yield config
    end
  end
end
