# frozen_string_literal: true

require "active_model/type"

# Reopened to register poetry's option types alongside Rails' own.
module ActiveModel
  # Reopened: poetry registers its list (and symbol) attribute types here
  # so the option/style DSLs can declare them.
  module Type
    # A string-array option type (Accordion's open:, future multi-selects).
    # Casts scalars to one-element arrays and stringifies members, so
    # open: :shipping and open: %w[a b] both normalize.
    class List < ActiveModel::Type::Value
      # Reports :list to introspection (prop_definitions, the registry).
      #
      # @return [Symbol]
      def type
        :list
      end

      # Normalizes any value to an array of strings: nil becomes [], a
      # scalar becomes a one-element array, and members are stringified.
      #
      # @param value [Object] the declared option value
      # @return [Array<String>]
      def cast(value)
        return [] if value.nil?

        Array(value).map(&:to_s)
      end
    end
  end
end
