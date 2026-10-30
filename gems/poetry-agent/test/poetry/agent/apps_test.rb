# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "json"

module Poetry
  module Agent
    # The author's side of MCP Apps: a document per ui:// resource, the
    # fragments a result carries for the page, and the shapes the host reads,
    # held to the extension's own schema.
    class AppsTest < Minitest::Test
      SCHEMA_PATH = File.expand_path("../../fixtures/mcp_apps/upstream/src/generated/schema.json", __dir__)
      SCHEMA_URI = "https://poetry.test/mcp-apps/schema.json"

      # A renderer that records what it was asked and answers a marker.
      class FakeRenderer
        attr_reader :calls

        def initialize = @calls = []

        def render(**options)
          @calls << options
          "<rendered #{options[:template] || options[:partial]}>"
        end
      end

      # A view with the tag helpers the head uses.
      class FakeView
        Tag = Struct.new(:nothing) do
          def script(content, type:) = %(<script type="#{type}">#{content}</script>)
          def style(content) = %(<style>#{content}</style>)
        end

        def tag = Tag.new
        def safe_join(parts, separator) = parts.join(separator)
        def stylesheet_link_tag(name, host:) = %(<link rel="stylesheet" href="#{host}/assets/#{name}-abc.css">)
      end

      def schema(definition)
        @documents ||= { SCHEMA_URI => JSON.parse(File.read(SCHEMA_PATH)) }
        A2UI::Schema.new(documents: @documents, root: "#{SCHEMA_URI}#/$defs/#{definition}")
      end

      def document(**)
        Apps::Document.new(uri: "ui://shop/plans", name: "plans", template: "apps/plans",
                           origin: "https://shop.example", **)
      end

      # --- fragments and results ---

      def test_a_fragment_is_a_region_an_action_and_html
        fragment = Apps::Fragment.new(target: "plans", html: "<p>Pro</p>")

        assert_equal({ "target" => "plans", "action" => "replace", "html" => "<p>Pro</p>" }, fragment.to_h)
        assert_equal({ "target" => "plans", "action" => "remove" },
                     Apps::Fragment.new(target: "plans", action: :remove).to_h)
        assert_raises(ArgumentError) { Apps::Fragment.new(target: "", html: "x") }
        assert_raises(ArgumentError) { Apps::Fragment.new(target: "plans", html: "x", action: :morph) }
        assert_raises(ArgumentError) { Apps::Fragment.new(target: "plans") }
      end

      def test_a_result_carries_text_for_the_model_data_for_the_host_and_fragments_in_meta
        result = Apps.result(text: "Three plans.", data: { "recommended" => "pro" },
                             fragments: [Apps.fragment("plans", "<p>Pro</p>")])
        wire = result.to_h

        assert_equal [{ type: "text", text: "Three plans." }], wire[:content]
        assert_equal({ "recommended" => "pro" }, wire[:structuredContent])
        fragment = { "target" => "plans", "action" => "replace", "html" => "<p>Pro</p>" }

        assert_equal({ "poetry" => { "fragments" => [fragment] } }, wire[:_meta])
        refute wire[:isError]
        notification = { "method" => "ui/notifications/tool-result", "params" => JSON.parse(JSON.generate(wire)) }

        assert_empty schema("McpUiToolResultNotification").errors(notification)
      end

      def test_a_result_without_fragments_carries_no_meta_and_an_error_says_so
        result = Apps.result(text: "No such plan.", error: true)

        assert_nil result.to_meta
        assert result.to_h[:isError]
        refute result.to_h.key?(:_meta)
        meta = Apps.result(text: "x", meta: { "trace" => "t1" }, fragments: [Apps.fragment("a", "<b>")]).to_meta

        assert_equal %w[trace poetry], meta.keys
      end

      def test_a_fragment_renders_a_partial_through_the_renderer
        renderer = FakeRenderer.new
        fragment = Apps.fragment("plans", partial: "apps/plans/table", locals: { size: 8 }, renderer: renderer)

        assert_equal "<rendered apps/plans/table>", fragment.html
        assert_equal [{ partial: "apps/plans/table", locals: { size: 8 } }], renderer.calls
      end

      # --- documents ---

      def test_a_document_is_a_ui_resource_with_a_tool_meta_and_the_csp_naming_its_origin
        doc = document(title: "Plans", description: "The plan picker", connect: ["https://api.example"])

        assert_equal "ui://shop/plans", doc.resource.uri
        assert_equal Apps::Document::MIME_TYPE, doc.resource.mime_type
        assert_equal "Plans", doc.resource.title
        assert_equal({ ui: { resourceUri: "ui://shop/plans" } }, doc.tool_meta)
        assert_equal({ ui: { resourceUri: "ui://shop/plans", visibility: ["app"] } },
                     doc.tool_meta(visibility: ["app"]))
        assert_equal({ "csp" => { "connectDomains" => ["https://shop.example", "https://api.example"],
                                  "resourceDomains" => ["https://shop.example"] } }, doc.ui_meta)
        assert doc.serves?("ui://shop/plans")
        refute doc.serves?("ui://shop/other")
        assert_empty schema("McpUiResourceMeta").errors(doc.ui_meta)
        assert_empty schema("McpUiToolMeta").errors(JSON.parse(JSON.generate(doc.tool_meta[:ui])))
      end

      def test_an_inline_document_declares_no_origin_and_keeps_the_permissions_border_and_domain
        doc = document(assets: :inline, permissions: %i[camera clipboard_write], prefers_border: true,
                       domain: "abc.claudemcpcontent.com", frames: ["https://maps.example"])
        meta = doc.ui_meta

        assert_equal({ "frameDomains" => ["https://maps.example"] }, meta["csp"])
        assert_equal({ "camera" => {}, "clipboardWrite" => {} }, meta["permissions"])
        assert meta["prefersBorder"]
        assert_equal "abc.claudemcpcontent.com", meta["domain"]
        assert_empty schema("McpUiResourceMeta").errors(meta)
      end

      def test_a_document_refuses_a_bad_uri_strategy_mapping_or_a_missing_origin
        assert_raises(ArgumentError) { Apps::Document.new(uri: "https://x", name: "x", template: "t", origin: "https://o") }
        assert_raises(ArgumentError) { document(assets: :cdn) }
        assert_raises(ArgumentError) { document(host_styles: :some) }
        assert_raises(ArgumentError) { Apps::Document.new(uri: "ui://x/y", name: "x", template: "t") }
        assert_equal "ui://x/y", Apps::Document.new(uri: "ui://x/y", name: "x", template: "t", assets: :inline).uri
      end

      def test_the_origin_can_be_the_request_s_own
        doc = Apps::Document.new(uri: "ui://x/y", name: "x", template: "t", origin: :request,
                                 html: { class: "style-default" })

        assert_raises(ArgumentError) { doc.origin }
        Apps.with_request_origin("https://docs.example/") do
          assert_equal "https://docs.example", doc.origin
          assert_equal ["https://docs.example"], doc.csp["resourceDomains"]
        end
        assert_equal({ class: "style-default" }, doc.html_attributes)
      end

      def test_the_contents_render_the_template_in_the_engine_layout
        renderer = FakeRenderer.new
        doc = document(renderer: renderer, locals: { team: "ops" })
        contents = doc.contents

        assert_equal "ui://shop/plans", contents[:uri]
        assert_equal Apps::Document::MIME_TYPE, contents[:mimeType]
        assert_equal "<rendered apps/plans>", contents[:text]
        assert_equal({ "ui" => doc.ui_meta }, contents[:_meta])
        assert_equal [{ template: "apps/plans", layout: "poetry/agent/apps/document", assigns: { poetry_app: doc },
                        locals: { team: "ops" } }], renderer.calls
      end

      def test_the_reader_answers_each_document_at_its_uri
        plans = document(renderer: FakeRenderer.new)
        cart = Apps::Document.new(uri: "ui://shop/cart", name: "cart", template: "apps/cart", origin: "https://shop.example",
                                  renderer: FakeRenderer.new)
        reader = Apps.reader(plans, [cart])

        assert_equal(["ui://shop/cart"], reader.call({ uri: "ui://shop/cart" }).map { |item| item[:uri] })
        assert_equal(["ui://shop/plans"], reader.call({ "uri" => "ui://shop/plans" }).map { |item| item[:uri] })
        assert_empty reader.call({ uri: "ui://shop/none" })
      end

      def test_the_capabilities_declare_tools_resources_and_the_extension
        capabilities = Apps.capabilities.to_h

        assert capabilities.key?(:tools)
        assert capabilities.key?(:resources)
        assert_equal({ mimeTypes: [Apps::Document::MIME_TYPE] },
                     capabilities.dig(:extensions, "io.modelcontextprotocol/ui"))
      end

      def test_the_absolute_head_links_the_stylesheets_and_imports_from_the_origin
        importmap = JSON.generate("imports" => { "application" => "/assets/application-1.js",
                                                 "@poetry/agent/mcp_app" => "/assets/poetry/agent/mcp_app-2.js" })
        head = document(stylesheets: %w[tailwind]).head(FakeView.new, importmap: importmap)

        assert_includes head, %(<link rel="stylesheet" href="https://shop.example/assets/tailwind-abc.css">)
        assert_includes head, %("application":"https://shop.example/assets/application-1.js")
        assert_includes head, %("@poetry/agent/mcp_app":"https://shop.example/assets/poetry/agent/mcp_app-2.js")
        assert_includes head, %(<script type="module">import "@poetry/agent/mcp_app"\nimport "application"</script>)
        refute_includes head, "<base"
        bare = document(entrypoint: nil).head(FakeView.new, importmap: importmap)

        assert_includes bare, %(<script type="module">import "@poetry/agent/mcp_app"</script>)
      end

      def test_the_inline_head_writes_the_stylesheets_and_the_bridge_into_the_document
        Dir.mktmpdir do |dir|
          builds = Pathname(dir)
          builds.join("application.css").write(".x{color:red}")
          pipeline = {}
          head = with_builds(pipeline, builds) { document(assets: :inline).head(FakeView.new) }

          assert_includes head, "<style>.x{color:red}</style>"
          assert_includes head, %(<script type="module">)
          assert_includes head, "export class Bridge"
          assert_raises(ArgumentError) { Apps::Assets.stylesheet("missing", pipeline: pipeline, builds: builds) }
        end
      end

      # Points the inline stylesheet lookup at a pipeline and a builds
      # directory of the test's own (no Rails here).
      def with_builds(pipeline, builds)
        Apps::Assets.singleton_class.alias_method(:stylesheet_without_rails, :stylesheet)
        Apps::Assets.define_singleton_method(:stylesheet) do |name, **|
          stylesheet_without_rails(name, pipeline: pipeline, builds: builds)
        end
        yield
      ensure
        Apps::Assets.singleton_class.alias_method(:stylesheet, :stylesheet_without_rails)
        Apps::Assets.singleton_class.remove_method(:stylesheet_without_rails)
      end

      def test_the_stylesheet_comes_from_a_pipeline_that_knows_it
        propshaft = Struct.new(:load_path).new(Struct.new(:found) do
          def find(_file)
            found
          end
        end.new(Struct.new(:content).new("a{}")))
        sprockets = { "app.css" => "b{}" }

        assert_equal "a{}", Apps::Assets.stylesheet("app", pipeline: propshaft, builds: Pathname("/nowhere"))
        assert_equal "b{}", Apps::Assets.stylesheet("app.css", pipeline: sprockets, builds: Pathname("/nowhere"))
      end

      def test_the_default_renderer_is_the_application_controller_when_one_exists
        assert_equal ActionController::Base, Apps.renderer unless defined?(::ApplicationController)
        Apps.renderer = FakeRenderer.new

        assert_kind_of FakeRenderer, Apps.renderer
      ensure
        Apps.renderer = nil
      end
    end
  end
end
