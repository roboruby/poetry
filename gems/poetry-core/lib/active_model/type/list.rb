# frozen_string_literal: true

require "active_model/type"

module ActiveModel
  module Type
    # A string-array option type (Accordion's open:, future multi-selects).
    # Casts scalars to one-element arrays and stringifies members, so
    # open: :shipping and open: %w[a b] both normalize.
    class List < ActiveModel::Type::Value
      def type
        :list
      end

      def cast(value)
        return [] if value.nil?

        Array(value).map(&:to_s)
      end
    end
  end
end
