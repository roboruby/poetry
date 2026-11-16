# frozen_string_literal: true

require "erb"

module Poetry
  module Ui
    # poetry_markdown's parser seam. Parsing Markdown is a SOFT
    # capability, as highlighting is for CodeBlock: `gem "commonmarker"`
    # (or `gem "redcarpet"`) in the host Gemfile turns it on, and without
    # either the text renders as plain paragraphs with its fenced code
    # kept as code. Whatever writes the HTML here, the Markdown component
    # rebuilds it from the elements it knows, so no parser decides what
    # reaches the page.
    #
    # A host with another parser, or with options of its own, sets
    # {renderer} to anything that answers call(text) with HTML:
    #
    # @example
    #   Poetry::Ui::MarkdownParser.renderer = ->(text) { Kramdown::Document.new(text, input: "GFM").to_html }
    module MarkdownParser
      # The gems read for, in order of preference.
      GEMS = %i[commonmarker redcarpet].freeze
      # Commonmarker's extensions for a reply: what GitHub-flavored
      # Markdown adds, without heading anchors or task-list inputs.
      COMMONMARKER_EXTENSIONS = { table: true, strikethrough: true, autolink: true, tagfilter: true,
                                  tasklist: false, header_ids: nil }.freeze
      # Redcarpet's extensions for the same.
      REDCARPET_EXTENSIONS = { tables: true, fenced_code_blocks: true, strikethrough: true, autolink: true,
                               no_intra_emphasis: true, lax_spacing: true, space_after_headers: true }.freeze
      # An opening or closing code fence in the plain rendering.
      FENCE = /\A {0,3}(`{3,}|~{3,})\s*([\w+#.-]*)/

      class << self
        # A host's own renderer: anything answering call(text) with HTML.
        # It takes the place of the bundled gems.
        #
        # @return [#call, nil]
        attr_accessor :renderer

        # The parser in use: :custom for a host's renderer, a gem's name,
        # or nil when the host bundles none (memoized).
        #
        # @return [Symbol, nil]
        def parser
          return :custom if renderer

          @parser = GEMS.find { |name| loadable?(name) } || false unless defined?(@parser)
          @parser || nil
        end

        # Names the parser to use when the host bundles both gems, or
        # false for the plain rendering. nil reads the bundle again.
        #
        # @param name [Symbol, false, nil] :commonmarker, :redcarpet, false, or nil
        def parser=(name)
          if name.nil?
            remove_instance_variable(:@parser) if defined?(@parser)
          elsif name != false && !GEMS.include?(name)
            raise ArgumentError, "unknown Markdown parser #{name.inspect}"
          elsif name && !loadable?(name)
            raise LoadError, "#{name} is not in the bundle"
          else
            @parser = name
          end
        end

        # Whether Markdown is parsed here, or rendered plain.
        #
        # @return [Boolean]
        def available? = !parser.nil?

        # The Markdown as HTML, from the parser in use, or from the plain
        # rendering when there is none. The HTML is a parser's own: only
        # the Markdown component, which rebuilds it, may put it on a page.
        #
        # @param text [String] the Markdown
        # @param hard_breaks [Boolean] whether a line break in a paragraph is kept
        # @param with [Symbol, nil] a parser to use in place of the one in use
        # @return [String]
        def to_html(text, hard_breaks: false, with: parser)
          text = text.to_s
          case with
          when :custom then renderer.call(text).to_s
          when :commonmarker then commonmarker(text, hard_breaks)
          when :redcarpet then redcarpet(text, hard_breaks)
          else plain(text)
          end
        end

        # The plain rendering: the text escaped, a paragraph per block
        # with its line breaks kept, and fenced code as code.
        #
        # @param text [String]
        # @return [String]
        def plain(text)
          html = +""
          paragraph = []
          code = nil
          flush = lambda do
            html << "<p>#{paragraph.map { |line| ERB::Util.html_escape(line) }.join("<br>\n")}</p>\n" if paragraph.any?
            paragraph = []
          end
          text.each_line(chomp: true) do |line|
            fence = line.match(FENCE)
            if code
              next code[:lines] << line unless fence && fence[1][0] == code[:marker][0] && line.strip == fence[1]

              html << fenced(code)
              code = nil
            elsif fence
              flush.call
              code = { marker: fence[1], language: fence[2], lines: [] }
            elsif line.strip.empty?
              flush.call
            else
              paragraph << line
            end
          end
          flush.call
          html << fenced(code) if code
          html
        end

        private

        # Whether the host bundles a gem this seam can use.
        def loadable?(name)
          require name.to_s
          name == :commonmarker ? ::Commonmarker.respond_to?(:to_html) : true
        rescue LoadError
          false
        end

        # Raw HTML in the text is escaped, not left out: a reply about
        # markup has to be able to name a tag.
        def commonmarker(text, hard_breaks)
          require "commonmarker"
          ::Commonmarker.to_html(text, options: { render: { unsafe: false, escape: true, hardbreaks: hard_breaks },
                                                  extension: COMMONMARKER_EXTENSIONS },
                                       plugins: { syntax_highlighter: nil })
        end

        # Redcarpet escapes raw HTML itself.
        def redcarpet(text, hard_breaks)
          require "redcarpet"
          renderer = ::Redcarpet::Render::HTML.new(escape_html: true, hard_wrap: hard_breaks)
          ::Redcarpet::Markdown.new(renderer, REDCARPET_EXTENSIONS).render(text)
        end

        # A fence's lines as a code element, its language as the class parsers write.
        def fenced(code)
          language = %( class="language-#{code[:language]}") unless code[:language].empty?
          "<pre><code#{language}>#{ERB::Util.html_escape(code[:lines].join("\n"))}</code></pre>\n"
        end
      end
    end
  end
end
