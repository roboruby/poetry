# frozen_string_literal: true

require "date"

module Poetry
  module Ui
    # Reads the date values a calendar-style component accepts (Calendar,
    # DatePicker): a single value as a Date, and a range as its two ends
    # from a Range, a pair, a start and end hash, or one starting value.
    module DateParsing
      private

      # A value as a Date, parsed from text; nil stays nil.
      def to_date(value)
        return if value.nil?
        return value if value.is_a?(Date)

        Date.parse(value.to_s)
      end

      # A preselected range: Date..Date, [start, end], or {start:, end:}.
      def parse_range(value)
        case value
        when nil then [nil, nil]
        when Range then [to_date(value.first), to_date(value.last)]
        when Array then [to_date(value[0]), to_date(value[1])]
        when Hash
          pair = value.symbolize_keys
          [to_date(pair[:start]), to_date(pair[:end])]
        else
          [to_date(value), nil] # a single value starts the range
        end
      end
    end
  end
end
