# frozen_string_literal: true

require "json"

module Poetry
  module Agent
    module Apps
      class Host
        # The sandbox proxy page and the Rack app that serves it. The page is
        # the outer frame on the apps origin: it creates the inner frame for
        # the app's HTML, relays messages between the host page and the app,
        # and answers to the host origin only. Served per resource under a
        # signed token, with the resource's policy as a header, so the HTML
        # cannot precede it. The same page, with the policy in a meta
        # element, is what the inline mode writes into a frame of its own.
        class Sandbox
          # The sandbox pages of one host.
          # @param host [Host] the host whose origin the pages answer to
          def initialize(host)
            @host = host
          end

          # The Rack entry point: `GET /<token>`.
          #
          # @param env [Hash] the Rack environment
          # @return [Array(Integer, Hash, Array<String>)]
          def call(env)
            return [405, { "allow" => "GET, HEAD" }, []] unless %w[GET HEAD].include?(env["REQUEST_METHOD"])

            token = env["PATH_INFO"].to_s.delete_prefix("/")
            claim = @host.verify_sandbox_token(token)
            return [403, { "content-type" => "text/plain" }, ["forbidden"]] unless claim

            resource = @host.resource(claim["server"], claim["uri"])
            headers = {
              "content-type" => "text/html; charset=utf-8",
              "content-security-policy" => Csp.header(resource.ui, frame_ancestors: @host.origin),
              "cache-control" => "no-store",
              "referrer-policy" => "no-referrer"
            }
            body = env["REQUEST_METHOD"] == "HEAD" ? [] : [page]
            [200, headers, body]
          rescue Refused => e
            [404, { "content-type" => "text/plain" }, [e.message]]
          end

          # The page's HTML, for the origin mode (no policy inside: the header
          # carries it) or the inline mode (the policy as a meta element, where
          # a browser ignores `frame-ancestors`, so the inline policy omits it).
          #
          # @param csp [String, nil] the policy for a meta element
          # @return [String]
          def page(csp: nil)
            meta = csp ? %(    <meta http-equiv="Content-Security-Policy" content="#{csp.gsub('"', "&quot;")}">\n) : ""
            <<~HTML
              <!doctype html>
              <html>
                <head>
                  <meta charset="utf-8">
              #{meta}    <meta name="color-scheme" content="light dark">
                  <title>MCP App sandbox</title>
                  <style>
                    html, body { margin: 0; height: 100vh; width: 100vw; background: transparent; }
                    body { display: flex; flex-direction: column; }
                    * { box-sizing: border-box; }
                    iframe { background: transparent; border: 0; padding: 0; overflow: hidden; flex-grow: 1; color-scheme: inherit; }
                  </style>
                </head>
                <body>
                  <script>#{script}</script>
                </body>
              </html>
            HTML
          end

          # The relay script: the host origin baked in, never read from the
          # referrer; the inner frame's sandbox flags per the extension; the
          # app's HTML written on `sandbox-resource-ready`. Semicolons and no
          # line comments, since the page may travel inside an attribute whose
          # newlines a stream collapses.
          #
          # @return [String]
          def script
            <<~JS
              (() => {
                const HOST_ORIGIN = #{JSON.generate(@host.origin)};
                const OWN_ORIGIN = window.location.origin;
                const INNER_SANDBOX = #{JSON.generate(@host.sandbox_origin ? "allow-scripts allow-same-origin allow-forms" : "allow-scripts allow-forms")};
                if (window.self === window.top) { throw new Error("the sandbox page is only ever framed"); }
                try { window.top.alert("sandbox is not isolated"); throw "FAIL"; } catch (e) { if (e === "FAIL") { throw new Error("the sandbox is not isolated"); } }
                const inner = document.createElement("iframe");
                inner.style = "width:100%; height:100%; border:none;";
                inner.setAttribute("sandbox", INNER_SANDBOX);
                document.body.appendChild(inner);
                const allowFor = (permissions) => {
                  if (!permissions || typeof permissions !== "object") { return ""; }
                  const names = { camera: "camera", microphone: "microphone", geolocation: "geolocation", clipboardWrite: "clipboard-write" };
                  return Object.keys(permissions).map((key) => names[key]).filter(Boolean).join("; ");
                };
                window.addEventListener("message", (event) => {
                  if (event.source === window.parent) {
                    if (event.origin !== HOST_ORIGIN) { return; }
                    const data = event.data;
                    if (data && data.method === "ui/notifications/sandbox-resource-ready") {
                      const { html, sandbox, permissions } = data.params || {};
                      if (typeof sandbox === "string") { inner.setAttribute("sandbox", sandbox); }
                      const allow = allowFor(permissions);
                      if (allow) { inner.setAttribute("allow", allow); }
                      if (typeof html === "string") {
                        const doc = OWN_ORIGIN === "null" ? null : inner.contentDocument;
                        if (doc) { doc.open(); doc.write(html); doc.close(); } else { inner.srcdoc = html; }
                      }
                    } else if (inner.contentWindow) {
                      inner.contentWindow.postMessage(data, "*");
                    }
                  } else if (event.source === inner.contentWindow) {
                    if (OWN_ORIGIN !== "null" && event.origin !== OWN_ORIGIN) { return; }
                    window.parent.postMessage(event.data, HOST_ORIGIN);
                  }
                });
                window.parent.postMessage({ jsonrpc: "2.0", method: "ui/notifications/sandbox-proxy-ready", params: {} }, HOST_ORIGIN);
              })()
            JS
          end
        end
      end
    end
  end
end
