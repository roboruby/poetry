# frozen_string_literal: true

require "active_model/type"

module ActiveModel
  module Type
    # A symbol option type for the option DSL: casts anything responding
    # to #to_sym and reports :symbol to introspection.
    #
    # Strict by design: a value that cannot become a Symbol raises at
    # assignment - poetry surfaces bad option values where they are
    # written, not as a validation error nothing reads at render.
    # Leniency is List's job, not this type's.
    class Symbol < ActiveModel::Type::String
      # Without this the type reports :string (inherited) - introspection
      # (prop_definitions, the registry) must see :symbol.
      #
      # @return [Symbol] :symbol
      def type
        :symbol
      end

      # Casts a value to a Symbol; nil stays nil.
      #
      # @param value [#to_sym, nil] the raw option value
      # @return [Symbol, nil]
      # @raise [ArgumentError] when the value cannot become a Symbol
      def cast(value)
        return nil if value.nil?
        raise ArgumentError, "#{value.inspect} can't become a Symbol (no #to_sym)" unless value.respond_to?(:to_sym)

        value.to_sym
      end
    end
  end
end
