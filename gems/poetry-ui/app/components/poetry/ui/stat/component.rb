# frozen_string_literal: true

module Poetry
  module Ui
    # One KPI: a labelled value with an optional sentiment-aware delta.
    module Stat
      # One KPI: a muted label over a large tabular-nums value, with an
      # optional sentiment-aware delta, supporting description, and a
      # media slot for a trend visual. Reach for it on dashboards - one
      # Stat per metric, composed in a grid. Styling is utility-only:
      # data-slot names are the restyle seam.
      #
      # @example Revenue KPI with a delta
      #   render Poetry::Ui::Stat::Component.new(label: "Revenue", delta: "+12.5%", trend: :up) do
      #     "$45,231"
      #   end
      class Component < Poetry::Core::Component
        requires_content "the metric value"

        # The closed vocabulary for the trend axis.
        TRENDS = %i[up down flat].freeze
        # The closed vocabulary for the sentiment axis.
        SENTIMENTS = %i[positive negative neutral].freeze

        # trend picks the arrow; sentiment defaults FROM the trend (up is
        # good, down is bad) and is overridden when the metric inverts.
        DEFAULT_SENTIMENT = { up: :positive, down: :negative, flat: :neutral }.freeze
        # The arrow glyph each trend renders in the delta pill.
        TREND_ICON = { up: :"trending-up", down: :"trending-down", flat: :minus }.freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "One Stat is ONE metric: label: names it, the content block is the value - compose " \
          "several in a grid (typically each inside a Card) for a dashboard row.",
          "delta: carries the change text ('+12.5%'); trend: (up/down/flat) sets the arrow and " \
          "the default sentiment. Override sentiment: :positive when DOWN is the good direction " \
          "(costs, churn, error rate) - color follows sentiment, never the arrow.",
          "Keep the value textual - tabular numerals are already applied; units and formatting " \
          "belong in the content ('$45,231', '99.98%').",
          "A Stat is not a chart: a trend over time goes in the media slot (or use poetry-charts)."
        ].freeze

        renders_one :description, doc: "Muted supporting copy rendered under the value."
        renders_one :media, doc: "The trend-visual slot (sparkline, chart, glyph) below the text stack."

        option :label, :string, required: true, doc: "The metric's name, shown muted above the value."
        option :delta, :string, doc: "The change text shown in the pill beside the value (\"+12.5%\")."
        option :trend, :symbol, default: :up, doc: "The arrow direction; also derives the default sentiment."
        option :sentiment, :symbol,
               doc: "Overrides the trend-derived sentiment - color follows sentiment, never the arrow (set :positive " \
                    "when DOWN is the good direction)."

        validates :trend, inclusion: { in: TRENDS }
        validates :sentiment, inclusion: { in: SENTIMENTS }, allow_nil: true

        part "stat", "The stat root - a label/value/delta/description column"
        part "stat-label", "The muted metric name above the value"
        part "stat-value", "The metric itself - large, semibold, tabular numerals"
        part "stat-delta", "The change pill beside the value - arrow icon + delta text with an " \
                           "sr-only trend word",
             states: {
               "data-trend" => { condition: "always - the arrow direction",
                                 values: TRENDS.map(&:to_s) },
               "data-sentiment" => { condition: "always - resolved sentiment (trend-derived " \
                                                "unless overridden)",
                                     values: SENTIMENTS.map(&:to_s) }
             }
        part "stat-description", "Muted supporting copy under the value"
        part "stat-media", "The trend-visual slot (sparkline, chart, glyph) below the text stack"

        # @api private
        def before_render
          ensure_content!
        end

        # @api private
        def resolved_sentiment
          sentiment || DEFAULT_SENTIMENT.fetch(trend)
        end

        # @api private
        def delta_classes
          "#{css(:delta)} #{css(:"delta_#{resolved_sentiment}")}"
        end

        # @api private
        def trend_icon
          TREND_ICON.fetch(trend)
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "stat" }.merge(component_data_attributes)
          )
        end

        private :resolved_sentiment, :delta_classes, :trend_icon, :root_attributes
      end
    end
  end
end
