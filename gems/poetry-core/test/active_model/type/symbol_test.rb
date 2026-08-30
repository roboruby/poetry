# frozen_string_literal: true

require "test_helper"

module ActiveModel
  module Type
    class SymbolTest < Minitest::Test
      def test_cast_converts_string_to_symbol
        assert_equal :foo, Symbol.new.cast("foo")
      end

      def test_cast_returns_nil_for_nil
        assert_nil Symbol.new.cast(nil)
      end

      def test_cast_raises_for_non_symbolizable
        assert_raises(ArgumentError) { Symbol.new.cast(Object.new) }

        error = assert_raises(ArgumentError) { Symbol.new.cast(123) }

        assert_includes error.message, "123 can't become a Symbol"
      end

      def test_registered_as_active_model_type
        assert_instance_of Symbol, ActiveModel::Type.lookup(:symbol)
      end
    end
  end
end
