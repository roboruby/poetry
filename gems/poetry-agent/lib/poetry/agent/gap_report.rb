# frozen_string_literal: true

require "uri"

module Poetry
  module Agent
    # Something the library lacked for a task, written up so its owner can
    # hear of it: a component, a variant, an option or a block that was
    # missing, or documentation that was wrong. An agent that works around
    # a gap usually tells no one; this turns what it knows into an issue a
    # person can file with one click.
    #
    # Nothing is sent from here. The report is a title, a body and a link
    # that opens the repository's new-issue form with both filled in; the
    # person the agent is working for reads it and decides.
    #
    # @example
    #   report = GapReport.new(summary: "Badge has no warning variant", kind: "variant", component: "badge")
    #   report.url # => "https://github.com/roboruby/poetry/issues/new?title=Gap%3A+Badge+has+..."
    class GapReport
      # Where a report is filed.
      ISSUES = "https://github.com/roboruby/poetry/issues/new"
      # What a gap can be.
      KINDS = %w[component variant option block docs other].freeze
      # The most characters kept of the summary, and of each longer field:
      # the whole report has to fit in a link.
      SUMMARY_LIMIT = 120
      # The most characters kept of each longer field.
      FIELD_LIMIT = 600

      # A report of one gap; every field but the summary is optional.
      #
      # @param summary [String] the gap in one line
      # @param kind [String] one of {KINDS}; anything else reads as "other"
      # @param component [String, nil] the component or block it concerns
      # @param wanted [String, nil] what the task needed
      # @param workaround [String, nil] what was done instead
      # @param client [String, nil] the agent that met the gap, as it named itself
      def initialize(summary:, kind: "other", component: nil, wanted: nil, workaround: nil, client: nil)
        @summary = clip(summary, SUMMARY_LIMIT)
        @kind = KINDS.include?(kind.to_s) ? kind.to_s : "other"
        @component = clip(component, SUMMARY_LIMIT)
        @wanted = clip(wanted, FIELD_LIMIT)
        @workaround = clip(workaround, FIELD_LIMIT)
        @client = clip(client, SUMMARY_LIMIT)
      end

      # The issue's title.
      #
      # @return [String]
      def title
        "Gap: #{@summary}"
      end

      # The issue's body: one labelled line per thing known, then where
      # the report came from.
      #
      # @return [String]
      def body
        lines = { "Kind" => @kind, "Component" => @component, "What the task needed" => @wanted,
                  "What was done instead" => @workaround }.filter_map do |label, value|
          "**#{label}:** #{value}" unless value.empty?
        end
        source = ["poetry-agent #{Poetry::Agent::VERSION}", (@client unless @client.empty?)].compact.join(", ")
        (lines + ["", "Reported through #{source}."]).join("\n")
      end

      # The link that opens the new-issue form with the report filled in.
      #
      # @return [String]
      def url
        "#{ISSUES}?#{URI.encode_www_form(title: title, body: body, labels: "gap")}"
      end

      # The report as an agent or a terminal shows it: that nothing was
      # sent, the link, then what the link holds.
      #
      # @return [String]
      def to_s
        ["Nothing was sent. To report this, open the link and press Submit:", url, "",
         "What it holds:", "Title: #{title}", body].join("\n")
      end

      private

      # A field as one clean run of text, cut to a length.
      def clip(text, limit)
        text = text.to_s.gsub(/\s+/, " ").strip
        text.length > limit ? "#{text[0, limit - 1].rstrip}…" : text
      end
    end
  end
end
