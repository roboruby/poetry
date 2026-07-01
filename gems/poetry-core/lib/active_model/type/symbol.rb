# frozen_string_literal: true

require "active_model/type"

module ActiveModel
  module Type
    class Symbol < ActiveModel::Type::String
      # Without this the type reports :string (inherited) - introspection
      # (prop_definitions, the registry) must see :symbol.
      def type
        :symbol
      end

      def cast(value)
        return nil if value.nil?
        raise ArgumentError, "#{value} doesn't respond to #to_sym" unless value.respond_to?(:to_sym)

        value.to_sym
      end
    end
  end
end
