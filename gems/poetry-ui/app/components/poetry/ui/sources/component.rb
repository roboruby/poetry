# frozen_string_literal: true

module Poetry
  module Ui
    # Sources family: what a reply rests on, listed under it.
    module Sources
      # The sources a reply cites, in a disclosure under it: a count to
      # open ("3 sources"), then each source numbered as the reply cites
      # it, with its title as a link, the site it is on, and optionally
      # the passage it was cited for. The numbers are the ones the
      # citations in the text carry.
      #
      # @example
      #   render Poetry::Ui::Sources::Component.new do |sources|
      #     sources.with_source("Fulfilment guide", href: "https://example.com/fulfilment")
      #     sources.with_source("Refund policy", href: "https://example.com/refunds",
      #                         description: "Refunds are issued within five working days.")
      #   end
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "The sources a reply cites are a poetry_sources under it, one with_source(title, href:, " \
          "description:) each - never a hand-rolled list of links.",
          "Add sources in the order the reply first cites them: an entry's number is its position, and " \
          "that is the number its citations carry.",
          "description: is the passage the source was cited for - a quote, not a summary of yours.",
          "open: true shows the list from the start; the count is always the control that opens it.",
          "A title or an address that came from a model or a tool is safe to pass: text is escaped, and " \
          "only an http, https, mailto or tel address, or one on the host, becomes a link."
        ].freeze

        # The required slots, stated statically so static checks can flag
        # a missing source without rendering.
        REQUIRED_SLOTS = { source: "at least one source (with_source(title, href:))" }.freeze

        use_stimulus do
          on :root do
            controller(:state) { register }
          end
          on :trigger do
            controller :state do
              target :trigger
              action :toggle, on: :click
            end
          end
          on :content do
            controller(:state) { target :content }
          end
        end

        renders_many :sources,
                     doc: "One source: its title (positional), href: (its address - the title links to it), " \
                          "and description: (the passage it was cited for).",
                     renders: lambda { |title, href: nil, description: nil|
                       item(title.to_s, href: Addresses.link(href), description: description.to_s.presence)
                     }

        option :open, :boolean, default: false, doc: "Shows the list from the start."
        option :label, :string,
               doc: "The control's text. Defaults to the locale's count, \"3 sources\"."

        part "sources", "The root - the disclosure: its state rides here",
             states: {
               "data-open" => "the list is shown (server-rendered from open:; the controller flips the pair)",
               "data-closed" => "the list is hidden"
             }
        part "sources-trigger", "The control that opens the list - the count, in the ghost Button's dress; " \
                                "mirrors aria-expanded"
        part "sources-content", "The panel the control opens (hidden while closed)",
             states: {
               "data-open" => "the panel is open or entering",
               "data-closed" => "the panel is closed"
             }
        part "sources-list", "The numbered list (an <ol>) inside the panel"
        part "sources-item", "One source's row - its number, then its title, site and passage"
        part "sources-body", "The column beside the number - the heading line, then the passage"
        part "sources-heading", "The heading line - the title and the site"
        part "sources-title", "The source's title - a Link to its address, or plain text without one"
        part "sources-site", "The site the address is on (example.com), for a web address"
        part "sources-description", "The passage the source was cited for (description:)"

        # Raises without a source.
        # @api private
        def before_render
          raise ArgumentError, "Sources requires at least one with_source" unless sources?
        end

        # Renders the control, then the panel that holds the list.
        # @api private
        def call
          state = open ? "open" : "closed"
          panel_id = "#{poetry_instance_id("poetry-sources")}-list"
          content_tag(:div, trigger(panel_id) + panel(panel_id, state), **root_attributes({ "data-#{state}" => "" }))
        end

        private

        # The control: the count and a chevron, in the ghost Button's dress.
        def trigger(panel_id)
          words = label.presence || t("poetry.sources.count", count: sources.size)
          dress = classnames(Button::Style.css(variant: :ghost, size: :sm), css(:trigger))
          content_tag(:button, safe_join([words, render(Icon::Component.new(name: :"chevrons-up-down"))]),
                      **element_attributes(:trigger, { "type" => "button", "aria-expanded" => open.to_s,
                                                       "aria-controls" => panel_id, "class" => dress }))
        end

        # The panel: the numbered list, hidden while closed.
        def panel(panel_id, state)
          list = content_tag(:ol, safe_join(sources.map(&:to_s)), **element_attributes(:list))
          attrs = { "id" => panel_id, "data-#{state}" => "" }
          attrs["hidden"] = true unless open
          content_tag(:div, list, **element_attributes(:content, attrs))
        end

        # One row: the number as the citations show it, then the source.
        def item(title, href:, description:)
          body = [content_tag(:span, safe_join([title_markup(title, href), site(href)].compact),
                              **element_attributes(:heading))]
          body << content_tag(:span, description, **element_attributes(:description)) if description
          content_tag(:li, **element_attributes(:item)) do
            safe_join([render(Citation::Component.new(number: next_number)),
                       content_tag(:span, safe_join(body), **element_attributes(:body))])
          end
        end

        # The title as a link to the source, or as text when it has no address the page may carry.
        def title_markup(title, href)
          attrs = element_attributes(:title)
          return content_tag(:span, title, **attrs) unless href

          render(Link::Component.new(href: href, external: true, rel: Addresses::REL, **attrs.symbolize_keys)) { title }
        end

        # The site a web address is on.
        def site(href)
          host = Addresses.host(href) or return
          content_tag(:span, host, **element_attributes(:site))
        end

        # Numbers the sources in the order they were added.
        def next_number
          @number = (@number || 0) + 1
        end
      end
    end
  end
end
