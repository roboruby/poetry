# frozen_string_literal: true

module Poetry
  module Agent
    module Apps
      # One `ui://` resource: the complete HTML document a host loads into
      # its sandbox, rendered through the app's own views, and the metadata
      # (`_meta.ui`) the host reads beside it.
      #
      # Assets reach the sandbox two ways. `assets: :absolute` (the default)
      # links the app's stylesheets and importmap from `origin`, which the
      # document declares in the resource's CSP lists, so the Rails asset
      # pipeline and Poetry's controllers run inside the sandbox as they
      # are. `assets: :inline` writes the compiled stylesheets into the
      # document and leaves the page without a JavaScript runtime beyond
      # the bridge: the fallback for a host that loads nothing external.
      #
      # The page is a template: it renders once, before any call, and the
      # bridge fills its regions from the fragments each tool result
      # carries.
      class Document
        # The asset strategies.
        ASSETS = %i[absolute inline].freeze
        # How the host's style variables map onto Poetry's tokens: the
        # structural ones (backgrounds, text, borders, fonts; Poetry's
        # accents stay), all of them (the primary and destructive accents
        # too), or none.
        HOST_STYLES = %i[structural all none].freeze
        # The resource's MIME type.
        MIME_TYPE = ::MCP::Apps::RESOURCE_MIME_TYPE

        # The `ui://` URI.
        #
        # @return [String]
        attr_reader :uri

        # The display modes the extension names.
        DISPLAY_MODES = %w[inline fullscreen pip].freeze
        # The resource's name.
        #
        # @return [String]
        attr_reader :name
        # The template rendered as the page's body.
        #
        # @return [String]
        attr_reader :template
        # The asset strategy, absolute or inline.
        #
        # @return [Symbol]
        attr_reader :assets
        # The stylesheets the page links or inlines.
        #
        # @return [Array<String>]
        attr_reader :stylesheets
        # The importmap entry the page imports, with absolute assets.
        #
        # @return [String, nil]
        attr_reader :entrypoint
        # The host-style mapping: structural, all or none.
        #
        # @return [Symbol]
        attr_reader :host_styles

        # rubocop:disable Metrics/ParameterLists
        # @param uri [String] the `ui://` URI
        # @param name [String] the resource name
        # @param template [String] the template rendered as the page's body (`"apps/plans"`)
        # @param origin [String, Symbol, nil] the app's origin (`"https://shop.example"`), required for absolute
        #   assets; `:request` reads the origin of the request being served (see {Apps.with_request_origin})
        # @param assets [Symbol] `:absolute` or `:inline`
        # @param stylesheets [Array<String>] the stylesheet names (`"application"` by default)
        # @param entrypoint [String, nil] the importmap entry to import with absolute assets; nil imports none
        # @param host_styles [Symbol] `:structural`, `:all` or `:none`
        # @param title [String, nil] the resource title
        # @param description [String, nil] the resource description
        # @param connect [Array<String>] more origins the page may fetch from
        # @param resources [Array<String>] more origins the page may load scripts, styles, images and fonts from
        # @param frames [Array<String>] origins the page may embed in frames
        # @param permissions [Array<Symbol, String>] camera, microphone, geolocation, clipboard_write
        # @param prefers_border [Boolean, nil] whether the host should draw its border around the page
        # @param display_modes [Array<String, Symbol>] the display modes the page handles (`inline`, `fullscreen`,
        #   `pip`); the page declares them to the host, which offers no other
        # @param domain [String, nil] the host-specific sandbox origin (Claude's `ui.domain`)
        # @param locals [Hash] locals for the template
        # @param html [Hash] attributes for the document's `<html>` element (a theme class, say)
        # @param renderer [#render, nil] what renders the document (see {Apps.renderer})
        def initialize(uri:, name:, template:, origin: nil, assets: :absolute, stylesheets: ["application"],
                       entrypoint: "application", host_styles: :structural, title: nil, description: nil,
                       connect: [], resources: [], frames: [], permissions: [], prefers_border: nil,
                       display_modes: ["inline"], domain: nil, locals: {}, html: {}, renderer: nil)
          # rubocop:enable Metrics/ParameterLists
          @uri = uri.to_s
          @name = name.to_s
          @template = template
          @origin = origin == :request ? :request : origin&.to_s&.delete_suffix("/")
          @html_attributes = html
          @assets = assets.to_sym
          @stylesheets = Array(stylesheets)
          @entrypoint = entrypoint
          @host_styles = host_styles.to_sym
          @title = title
          @description = description
          @connect = Array(connect)
          @resources = Array(resources)
          @frames = Array(frames)
          @permissions = Array(permissions).map { |permission| permission.to_s.tr("_", "-") }
          @prefers_border = prefers_border
          @display_modes = Array(display_modes).map(&:to_s)
          @domain = domain
          @locals = locals
          @renderer = renderer
          validate!
        end

        # The app's origin the sandbox loads from: the one given, or the
        # request's own.
        # @return [String, nil]
        # @raise [ArgumentError] for `:request` outside a request
        def origin
          return @origin unless @origin == :request

          Apps.request_origin or raise ArgumentError,
                                       "the document reads the request's origin, and no request is being served"
        end

        # The attributes of the document's `<html>` element.
        # @return [Hash]
        attr_reader :html_attributes

        # The display modes the page handles, inline always among them.
        # @return [Array<String>]
        attr_reader :display_modes

        # The gem's resource, for the server's `resources:`.
        # @return [::MCP::Resource]
        def resource
          ::MCP::Apps.ui_resource(uri: uri, name: name, title: @title, description: @description)
        end

        # The `_meta` linking a tool to this document.
        #
        # @param visibility [Array<String>, nil] `["model"]`, `["app"]` or both (the default)
        # @param meta [Hash, nil] other `_meta` entries
        # @return [Hash]
        def tool_meta(visibility: nil, meta: nil)
          ::MCP::Apps.tool_meta(resource_uri: uri, visibility: visibility, meta: meta)
        end

        # Whether a read names this document.
        # @param candidate [String] a URI
        # @return [Boolean]
        def serves?(candidate) = candidate.to_s == uri

        # The `resources/read` contents item: the document and its `_meta.ui`.
        # @return [Hash]
        def contents
          { uri: uri, mimeType: MIME_TYPE, text: html, _meta: { "ui" => ui_meta } }
        end

        # The `_meta.ui` the host reads: the CSP lists (the app's origin
        # among them with absolute assets), the permissions, the border
        # preference and the sandbox domain.
        # @return [Hash]
        def ui_meta
          meta = { "csp" => csp }
          if @permissions.any?
            meta["permissions"] = @permissions.to_h do |permission|
              [permission.sub("clipboard-write", "clipboardWrite"), {}]
            end
          end
          meta["prefersBorder"] = @prefers_border unless @prefers_border.nil?
          meta["domain"] = @domain if @domain
          meta
        end

        # The resource's CSP lists.
        # @return [Hash]
        def csp
          own = assets == :absolute ? [origin] : []
          { "connectDomains" => (own + @connect).uniq, "resourceDomains" => (own + @resources).uniq,
            "frameDomains" => @frames, "baseUriDomains" => [] }.reject { |_, list| list.empty? }
        end

        # The document, rendered through the renderer: the template as the
        # body, inside the engine's layout, which writes the head.
        # @return [String]
        def html
          (@renderer || Apps.renderer).render(template: template, layout: "poetry/agent/apps/document",
                                              assigns: { poetry_app: self }, locals: @locals).to_s
        end

        # The head's asset tags for a view: the stylesheets linked from the
        # origin or inlined, the importmap with every path absolute and the
        # entry import, and the bridge, from the origin or inlined.
        #
        # @param view [ActionView::Base] the view rendering the layout, for its tag helpers
        # @param importmap [String, nil] the app's importmap JSON (absolute assets)
        # @return [ActiveSupport::SafeBuffer]
        def head(view, importmap: nil)
          view.safe_join(assets == :absolute ? absolute_head(view, importmap.to_s) : inline_head(view), "\n")
        end

        private

        # Refuses a document that cannot serve.
        #
        # @raise [ArgumentError] for an unknown strategy or mapping, or absolute assets without an origin
        def validate!
          unknown = @display_modes - DISPLAY_MODES
          raise ArgumentError, "unknown display modes: #{unknown.join(", ")}" unless unknown.empty?

          raise ArgumentError, "a document URI starts with ui://" unless uri.start_with?(::MCP::Apps::URI_SCHEME)
          raise ArgumentError, "assets: is one of #{ASSETS.join(", ")}" unless ASSETS.include?(assets)
          unless HOST_STYLES.include?(host_styles)
            raise ArgumentError,
                  "host_styles: is one of #{HOST_STYLES.join(", ")}"
          end
          return unless assets == :absolute && @origin.nil?

          raise ArgumentError,
                "absolute assets need the app's origin: pass origin:"
        end

        # Stylesheet links, the absolute importmap, the entry import and the bridge import.
        def absolute_head(view, importmap)
          tags = stylesheets.map { |name| view.stylesheet_link_tag(name, host: origin) }
          json = importmap.gsub('"/assets/', %("#{origin}/assets/))
          tags << view.tag.script(json.html_safe, type: "importmap")
          imports = ["@poetry/agent/mcp_app", entrypoint].compact.map { |specifier| %(import "#{specifier}") }
          tags << view.tag.script(imports.join("\n").html_safe, type: "module")
        end

        # The stylesheets' compiled sources and the bridge's source, inline.
        def inline_head(view)
          tags = stylesheets.map { |name| view.tag.style(Assets.stylesheet(name).html_safe) }
          tags << view.tag.script(Assets.bridge.html_safe, type: "module")
        end
      end

      # The compiled assets a document inlines.
      module Assets
        module_function

        # A compiled stylesheet's source, from the asset pipeline (propshaft
        # or sprockets) or the builds directory.
        #
        # @param name [String] the stylesheet name, without the extension
        # @param pipeline [Object, nil] the app's assets (`Rails.application.assets` by default)
        # @param builds [Pathname, nil] the builds directory (`app/assets/builds` by default)
        # @return [String]
        # @raise [ArgumentError] when no pipeline knows the name
        def stylesheet(name, pipeline: Rails.application.assets, builds: Rails.root.join("app/assets/builds"))
          file = "#{name.to_s.delete_suffix(".css")}.css"
          asset = pipeline.respond_to?(:load_path) ? pipeline.load_path.find(file) : pipeline&.[](file)
          return asset.respond_to?(:content) ? asset.content : asset.to_s if asset

          path = builds.join(file)
          return path.read if path.exist?

          raise ArgumentError, "no compiled stylesheet #{file} in the asset pipeline or app/assets/builds"
        end

        # The bridge module's source.
        # @return [String]
        def bridge
          @bridge ||= Poetry::Core.javascript_path(Poetry::Agent.root).join("poetry/agent/mcp_app.js").read
        end
      end
    end
  end
end
