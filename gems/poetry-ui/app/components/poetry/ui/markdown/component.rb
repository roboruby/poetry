# frozen_string_literal: true

require "nokogiri"

module Poetry
  module Ui
    # Markdown family: text written in Markdown, rendered as prose.
    module Markdown
      # Renders text a model or a person wrote in Markdown as prose, inside
      # a Typeset: headings, paragraphs, lists, quotes, links, tables in a
      # scroller, and fenced code as a CodeBlock. The page never receives
      # the parser's HTML. Every element is rebuilt from a short list, so
      # markup in the text, an unsafe link or a stray attribute has no way
      # through.
      #
      # While a reply is still being written, streaming: closes what its
      # last block has left open, so each frame reads as finished prose.
      # Parsing needs a Markdown gem in the host; without one the text
      # renders as plain paragraphs.
      #
      # @example
      #   render Poetry::Ui::Markdown::Component.new(text: message.content)
      #
      # @example A reply still being written
      #   render Poetry::Ui::Markdown::Component.new(text: reply.text, streaming: true, heading_level: 3)
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Text a model or a person wrote in Markdown renders with poetry_markdown(text:) - never html_safe, " \
          "raw, sanitize, or a Markdown gem called in the view. Markup in the text does not reach the page.",
          "Parsing needs `gem \"commonmarker\"` (or `gem \"redcarpet\"`) in the host Gemfile - without one " \
          "the text renders as plain paragraphs, with fenced code still a code block.",
          "While a reply streams, re-render its row with the longer text and streaming: true - an unfinished " \
          "**bold**, `code`, link or table is closed for display, so raw marks never flash. Render the " \
          "finished reply without it.",
          "Inside a transcript pass heading_level: 3, so a reply's # headings sit under the page's own.",
          "Images in the text render as links unless images: true - every reader's browser fetches a remote " \
          "image, which a reply shaped by untrusted content can use to send data out.",
          "It is a Typeset already (preset: retunes it) - never wrap it in poetry_typeset, and never pass it " \
          "HTML: the text is Markdown."
        ].freeze

        # Elements rebuilt as they stand, around their rebuilt children.
        CONTAINERS = %w[p strong em del s code blockquote ul li thead tbody tr].freeze
        # Elements with no content.
        VOIDS = %w[br hr].freeze
        # Elements left out with everything inside them.
        DROPPED = %w[script style iframe object embed template noscript svg math head title textarea select
                     option button].freeze
        # The schemes a link may use; an address with no scheme is the host's own.
        LINK_SCHEMES = %w[http https mailto tel].freeze
        # The schemes an image may load from.
        IMAGE_SCHEMES = %w[http https].freeze
        # What every link carries: the text is not the host's.
        LINK_REL = "nofollow noopener noreferrer"
        # A code fence's language as CodeBlock takes it.
        LANGUAGE = /\A[\w+#.-]{1,40}\z/
        # The cell alignments a table may ask for.
        ALIGNS = %w[left center right].freeze
        # The levels a # heading may render at.
        HEADING_LEVELS = (1..6).to_a.freeze

        option :text, :string, doc: "The Markdown to render. Blank renders the empty container, a reply's row " \
                                    "before its first word."
        option :streaming, :boolean, default: false,
                                     doc: "The text is still being written: what its last block has left open " \
                                          "(emphasis, a code span, a link's address, a table's first row) is " \
                                          "closed for display."
        option :preset, :string,
               doc: "Appends typeset-<preset>, as on Typeset - a tiny class in the app's own CSS retuning the " \
                    "rhythm variables."
        option :heading_level, :integer, default: 1,
                                         doc: "The level a # heading renders at; deeper headings follow, none " \
                                              "past h6."
        option :images, :boolean, default: false,
                                  doc: "Renders images in the text as images. Off, an image is a link to it."
        option :link_target, :string, doc: "The target every link opens in (\"_blank\" for a new tab)."
        option :hard_breaks, :boolean, default: false,
                                       doc: "Keeps a single line break inside a paragraph as a line break."

        validates :heading_level, inclusion: { in: HEADING_LEVELS }

        part "markdown", "The prose container - a Typeset, so the app-owned typeset.css styles every element " \
                         "inside and an embedded CodeBlock keeps its own styles",
             states: { "data-streaming" => "streaming: - the text is still being written" }

        # Renders the prose container around the rebuilt elements.
        # @api private
        def call
          content_tag(:div, body, **root_attributes)
        end

        # Attributes for the root.
        # @api private
        def root_attributes
          super(streaming ? { "data-streaming" => "" } : {})
        end

        # The preset rides the root class list, as on Typeset.
        # @api private
        def css(element = nil, **options)
          return super unless element.nil?

          classnames(super, ("typeset-#{preset}" if preset.present?))
        end

        private :css

        private

        # The text as rebuilt elements.
        def body
          source = text.to_s
          return "".html_safe if source.strip.empty?

          source = MarkdownTail.close(source) if streaming
          blocks(document(MarkdownParser.to_html(source, hard_breaks: hard_breaks)))
        end

        # The parser's HTML as a tree. HTML nested past the tree's depth
        # limit is not read at all: the text renders plain instead.
        def document(html)
          fragment(html)
        rescue ArgumentError
          fragment(MarkdownParser.plain(text.to_s))
        end

        # HTML as a tree, by the HTML5 parser where the platform has it.
        def fragment(html)
          defined?(Nokogiri::HTML5) ? Nokogiri::HTML5.fragment(html) : Nokogiri::HTML4.fragment(html)
        end

        # The document's own children: text a parser left outside any
        # block is given a paragraph, so the prose rhythm holds.
        def blocks(document)
          safe_join(document.children.map do |child|
            loose = child.text? && !child.content.strip.empty?
            loose ? content_tag(:p, child.content.strip) : element(child)
          end)
        end

        # A node's children, each written anew.
        def rebuild(node)
          safe_join(node.children.map { |child| element(child) })
        end

        # One node as the page receives it: text escaped, a known element
        # written anew, an unknown one reduced to its children.
        def element(node)
          return ERB::Util.html_escape(node.content) if node.text? || node.cdata?
          return "".html_safe unless node.element?

          case node.name
          when *CONTAINERS then content_tag(node.name, rebuild(node))
          when *VOIDS then tag.public_send(node.name)
          when *DROPPED then "".html_safe
          when "pre" then code_block(node)
          when "a" then link(node)
          when "img" then image(node)
          when "table" then content_tag(:div, content_tag(:table, rebuild(node)), class: css(:table_scroll))
          when "th", "td" then cell(node)
          when "ol" then content_tag(:ol, rebuild(node), start: node["start"].to_s[/\A\d{1,9}\z/])
          when /\Ah([1-6])\z/ then heading(node, Regexp.last_match(1).to_i)
          else rebuild(node)
          end
        end

        # A heading at its written level, moved down by heading_level and never past h6.
        def heading(node, written)
          level = written + heading_level.to_i.clamp(HEADING_LEVELS.first, HEADING_LEVELS.last) - 1
          content_tag("h#{[level, HEADING_LEVELS.last].min}", rebuild(node))
        end

        # Fenced code is a CodeBlock: the copy button, and highlighting
        # when the host bundles rouge. A fence with nothing in it yet (a
        # reply that has only just opened one) renders nothing.
        def code_block(node)
          code = node.at_css("code") || node
          return "".html_safe if code.content.strip.empty?

          render(CodeBlock::Component.new(code: code.content.chomp, language: language(node, code)))
        end

        # Parsers name the language three ways: on the pre, as the code's
        # class, and as that class behind a language- prefix.
        def language(pre, code)
          name = pre["lang"].presence || code["class"].to_s.split.first.to_s.delete_prefix("language-")
          name.match?(LANGUAGE) ? name : "text"
        end

        # A link with an address the page may carry; with any other, its label alone.
        def link(node)
          href = address(node["href"], LINK_SCHEMES, relative: true)
          return rebuild(node) unless href

          content_tag(:a, rebuild(node), href: href, title: node["title"].presence, rel: LINK_REL,
                                         target: link_target.presence)
        end

        # An image when images are asked for and its address may load; else a link to
        # it, or its alt text.
        def image(node)
          src = address(node["src"], IMAGE_SCHEMES)
          alt = node["alt"].to_s
          if images && src
            tag.img(src: src, alt: alt, title: node["title"].presence, loading: "lazy")
          elsif src
            content_tag(:a, alt.presence || src, href: src, rel: LINK_REL, target: link_target.presence)
          else
            ERB::Util.html_escape(alt)
          end
        end

        # A table cell with the alignment its column asked for, which parsers write as
        # an attribute or as a style.
        def cell(node)
          align = node["align"].presence || node["style"].to_s[/text-align:\s*(\w+)/, 1]
          content_tag(node.name, rebuild(node), class: (css(:"align_#{align}") if ALIGNS.include?(align)))
        end

        # An address the page may carry, or nil. A scheme has to be one
        # of the allowed ones. An address with none is the host's own: a
        # link may be one, since following it is the reader's choice, and
        # an image may not, since loading it is a request to the host with
        # the reader's session, made without asking. A colon before the
        # first slash that is not a scheme, and any control character,
        # refuse the address: browsers do not all read those alike.
        def address(value, schemes, relative: false)
          url = value.to_s.strip
          return if url.empty? || url.match?(/[[:cntrl:]]/)

          scheme = url[/\A([a-zA-Z][a-zA-Z0-9+.-]*):/, 1]
          return (url if schemes.include?(scheme.downcase)) if scheme

          url if relative && !url.start_with?("//") && !url[%r{\A[^/?#]*}].include?(":")
        end
      end
    end
  end
end
