# frozen_string_literal: true

module Poetry
  module Agent
    module Apps
      class Host
        # The Content Security Policy a sandbox page serves for an app, from
        # the resource's declared domains (`_meta.ui.csp`): the extension's
        # directives, its restrictive default when nothing is declared, and
        # a sanitizer that keeps a declared domain from smuggling a
        # directive. `frame-ancestors` names the host page's origin, so the
        # page can be framed by the host and nothing else.
        module Csp
          # Characters a domain may not carry: a `;` or a newline would start
          # a directive, a quote a keyword, a space a second source.
          UNSAFE = /[;\r\n'" ]/

          module_function

          # The declared domains that are safe to put in a directive.
          #
          # @param list [Array<String>, nil]
          # @return [String] the domains joined by spaces
          def domains(list)
            Array(list).select { |domain| domain.is_a?(String) && !domain.match?(UNSAFE) }.join(" ")
          end

          # The policy as a header value.
          #
          # @param meta [Hash] the resource's `_meta.ui` (string or symbol keys)
          # @param frame_ancestors [String, nil] the host page's origin; nil leaves the directive out, since a meta
          #   policy ignores it
          # @return [String]
          def header(meta, frame_ancestors:)
            csp = read(meta, :csp) || {}
            resource = domains(read(csp, :resourceDomains))
            connect = domains(read(csp, :connectDomains))
            frames = domains(read(csp, :frameDomains))
            base = domains(read(csp, :baseUriDomains))
            [
              "default-src 'none'",
              "script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: #{resource}".strip,
              "style-src 'self' 'unsafe-inline' blob: #{resource}".strip,
              "img-src 'self' data: blob: #{resource}".strip,
              "font-src 'self' data: blob: #{resource}".strip,
              "media-src 'self' data: blob: #{resource}".strip,
              "worker-src 'self' blob: #{resource}".strip,
              "connect-src 'self' #{connect}".strip,
              frames.empty? ? "frame-src 'none'" : "frame-src #{frames}",
              "object-src 'none'",
              base.empty? ? "base-uri 'self'" : "base-uri #{base}",
              frame_ancestors && "frame-ancestors #{frame_ancestors}"
            ].compact.join("; ")
          end

          # A member by symbol or string key.
          #
          # @param hash [Hash, nil]
          # @param key [Symbol]
          # @return [Object, nil]
          def read(hash, key)
            return nil unless hash.is_a?(Hash)

            hash[key] || hash[key.to_s]
          end
        end
      end
    end
  end
end
