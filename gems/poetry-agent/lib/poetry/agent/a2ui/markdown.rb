# frozen_string_literal: true

require "erb"

module Poetry
  module Agent
    module A2UI
      # The Markdown subset an A2UI Text component needs, rendered without
      # a Markdown dependency: ATX headings, paragraphs, bullet lists,
      # emphasis, strong, inline code, and links. Input is escaped first,
      # so agent text never reaches the page as markup.
      #
      # @example
      #   Markdown.render("## Login\nWelcome **back**") # => "<h2>Login</h2><p>Welcome <strong>back</strong></p>"
      module Markdown
        module_function

        # @param text [String]
        # @return [String] HTML (unmarked; wrap in `html_safe` at the render site)
        def render(text)
          blocks(text.to_s).map { |block| block_html(block) }.join
        end

        # Strips the same markers instead of rendering them - the
        # fallback the basic catalog guide asks for when markup is unwanted.
        #
        # @param text [String]
        # @return [String] plain text
        def strip(text)
          text.to_s.gsub(/^\#{1,6}\s+/, "").gsub(/\*\*(.+?)\*\*/, '\1').gsub(/(?<!\w)[*_](.+?)[*_](?!\w)/, '\1')
              .gsub(/`([^`]+)`/, '\1').gsub(/\[([^\]]+)\]\([^)]+\)/, '\1').gsub(/^[-*]\s+/, "")
        end

        # @api private
        def blocks(text)
          text.split(/\n{2,}/).map(&:strip).reject(&:empty?)
        end

        # @api private
        def block_html(block)
          if (match = block.match(/\A(\#{1,6})\s+(.*)\z/m))
            level = match[1].length
            "<h#{level}>#{inline(match[2].strip)}</h#{level}>"
          elsif block.lines.all? { |line| line.match?(/\A\s*[-*]\s+/) }
            items = block.lines.map { |line| "<li>#{inline(line.sub(/\A\s*[-*]\s+/, "").strip)}</li>" }
            "<ul>#{items.join}</ul>"
          else
            "<p>#{block.lines.map { |line| inline(line.strip) }.join("<br>")}</p>"
          end
        end

        # @api private
        def inline(text)
          html = ERB::Util.html_escape(text).to_str
          html = html.gsub(/`([^`]+)`/, '<code>\1</code>')
          html = html.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
          html = html.gsub(/(?<!\w)[*_](.+?)[*_](?!\w)/, '<em>\1</em>')
          html.gsub(%r{\[([^\]]+)\]\((https?://[^)\s]+)\)}, '<a href="\2">\1</a>')
        end
      end
    end
  end
end
