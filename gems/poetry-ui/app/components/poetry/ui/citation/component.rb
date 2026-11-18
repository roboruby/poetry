# frozen_string_literal: true

module Poetry
  module Ui
    # Citation family: the numbered mark that points a claim at its source.
    module Citation
      # A numbered mark set in a sentence, after the claim a source backs.
      # With href: it is a link to the source, named for assistive tech by
      # the source's title; without one it is the number alone, as a
      # sources list shows it beside each entry. poetry_markdown writes
      # these for the "[1]" marks in a reply when it is given sources:.
      #
      # @example
      #   render Poetry::Ui::Citation::Component.new(number: 2, href: source.url, title: source.title)
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "A source cited in a sentence is a poetry_citation(number:, href:, title:) - never a bracketed " \
          "number typed into the text or a bare superscript link.",
          "title: is the source's title: it names the link for assistive tech (\"Source 2: <title>\"), so " \
          "pass it whenever there is an href:.",
          "Numbers match the sources list under the reply (poetry_sources), in the order sources are first " \
          "cited.",
          "In a reply rendered by poetry_markdown, pass it sources: and let it place the citations - do not " \
          "render them by hand around Markdown."
        ].freeze

        option :number, :integer, required: true, doc: "The source's number, as the sources list shows it."
        option :href, :string,
               doc: "The source's address: the mark becomes a link to it. Only an http, https, mailto or tel " \
                    "address, or one on the host, is kept."
        option :title, :string, doc: "The source's title - the link's accessible name and its tooltip."

        part "citation", "The mark itself, in the Badge's dress - a link (<a>) when href: holds an address " \
                         "the page may carry, else a <span>"

        # Renders the mark: a link to its source, or the number alone.
        # @api private
        def call
          content_tag(address ? :a : :span, number.to_s, **root_attributes)
        end

        # Attributes for the root: for a link, its address, its name and
        # how it leaves the page.
        # @api private
        def root_attributes
          return super({}) unless address

          super({ "href" => address, "aria-label" => label, "title" => title.presence,
                  "rel" => Addresses::REL }.compact)
        end

        # The Badge's dictionary dresses the mark, so every theme does;
        # the citation's own classes set it in a line of prose.
        # @api private
        def css(element = nil, **options)
          return super unless element.nil?

          classnames(Badge::Style.css(variant: :secondary), super)
        end

        private :css

        private

        # The address as the page may carry it, or nil.
        def address
          @address ||= Addresses.link(href)
        end

        # "Source 2: Fulfilment guide", or "Source 2" for a source with no title.
        def label
          key = title.present? ? "poetry.citation.titled" : "poetry.citation.numbered"
          t(key, number: number, title: title)
        end
      end
    end
  end
end
