# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Poetry
  module Extract
    # The one model call: compose DESIGN.md from the fetched signals.
    # Prompt spec adapted from agentcn's design-md.ts (MIT; see
    # THIRD_PARTY_NOTICES.md; https://github.com/shadcn-labs/agentcn). Direct Anthropic Messages API over Net::HTTP
    # - no SDK dependency; the screenshot rides as a URL-source image block.
    module Compose
      ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
      ANTHROPIC_VERSION = "2023-06-01"
      DEFAULT_MODEL = "claude-sonnet-5"

      SPEC_SUMMARY = <<~SPEC.strip
        DESIGN.md is a self-contained plain-text representation of a design system. It contains optional YAML frontmatter with normative machine-readable tokens and a Markdown body with human-readable rationale.

        YAML frontmatter:
        - Must begin and end with a line containing exactly ---
        - Common top-level keys: version, name, description, colors, typography, rounded, spacing, components
        - Color values must be SRGB hex strings beginning with #
        - Typography tokens may include fontFamily, fontSize, fontWeight, lineHeight, letterSpacing, fontFeature, and fontVariation
        - Dimension units may be px, em, or rem; unitless lineHeight is allowed
        - Token references use {path.to.token}; component tokens may reference composite values

        Markdown body sections should appear in this order when relevant:
        1. Overview
        2. Colors
        3. Typography
        4. Layout
        5. Elevation & Depth
        6. Shapes
        7. Components
        8. Do's and Don'ts

        Recommended token names include colors primary, secondary, tertiary, neutral, surface, on-surface, error; typography headline-display, headline-lg, headline-md, body-lg, body-md, body-sm, label-lg, label-md, label-sm; rounded none, sm, md, lg, xl, full.
      SPEC

      SYSTEM = "You are a senior design systems writer. Produce concise, implementation-grade " \
               "DESIGN.md files that follow the requested spec."

      module_function

      def design_md(domain:, signals:, http: method(:post_anthropic))
        prompt = build_prompt(domain: domain, signals: signals)
        content = [text_block(prompt)]
        content.unshift(image_block(signals.screenshot_url)) if signals.screenshot_url

        response = http.call(
          model: ENV.fetch("POETRY_EXTRACT_MODEL", DEFAULT_MODEL),
          max_tokens: 4096,
          temperature: 0.2,
          system: SYSTEM,
          messages: [{ role: "user", content: content }]
        )
        extract_text(response).strip
      end

      def build_prompt(domain:, signals:)
        markdown_excerpt = signals.markdown.to_s.empty? ? "No Markdown returned." : signals.markdown[0, 3000]
        styleguide_json = JSON.pretty_generate(signals.styleguide)[0, 18_000]

        <<~PROMPT.strip
          Generate a polished DESIGN.md document for #{domain}.

          Follow this Google DESIGN.md specification summary:
          #{SPEC_SUMMARY}

          Use the Context.dev extracted styleguide as the primary source of design tokens. Use the screenshot URL and Markdown page content as supporting evidence for tone, component usage, and layout guidance.

          Requirements:
          - Return only DESIGN.md content, no commentary before or after it.
          - Include YAML frontmatter with version: alpha, name, description, colors, typography, rounded, spacing, and components.
          - Include the Markdown sections in the specified order.
          - Prefer precise values present in the Context.dev payload.
          - If data is missing, infer conservatively and state uncertainty in prose, not in token values.
          - Make Do's and Don'ts concrete enough for another AI agent to use.

          Context.dev styleguide JSON:
          #{styleguide_json}

          Screenshot URL:
          #{signals.screenshot_url || "No screenshot returned."}

          Homepage Markdown excerpt:
          #{markdown_excerpt}
        PROMPT
      end

      def text_block(text) = { type: "text", text: text }

      def image_block(url) = { type: "image", source: { type: "url", url: url } }

      def extract_text(response)
        Array(response["content"]).filter_map { |block| block["text"] if block["type"] == "text" }.join
      end

      def post_anthropic(payload)
        key = ENV.fetch("ANTHROPIC_API_KEY") do
          raise Error, "ANTHROPIC_API_KEY is required to compose DESIGN.md"
        end
        uri = URI(ANTHROPIC_URL)
        request = Net::HTTP::Post.new(uri)
        request["x-api-key"] = key
        request["anthropic-version"] = ANTHROPIC_VERSION
        request["content-type"] = "application/json"
        request.body = JSON.generate(payload)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 300) do |net|
          net.request(request)
        end
        raise Error, "Anthropic API error #{response.code}: #{response.body[0, 500]}" unless response.code == "200"

        JSON.parse(response.body)
      end
    end
  end
end
