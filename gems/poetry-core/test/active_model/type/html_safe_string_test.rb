# frozen_string_literal: true

require "test_helper"

module ActiveModel
  module Type
    class HtmlSafeStringTest < Minitest::Test
      def test_keeps_an_html_safe_string_html_safe
        value = "<b>bold</b>".html_safe

        cast = HtmlSafeString.new.cast(value)

        assert_predicate cast, :html_safe?
        assert_equal "<b>bold</b>", cast
      end

      def test_casts_a_plain_string_as_the_string_type_does
        cast = HtmlSafeString.new.cast("<b>bold</b>")

        assert_equal "<b>bold</b>", cast
        refute_predicate cast, :html_safe?
        assert_equal "sym", HtmlSafeString.new.cast(:sym)
        assert_equal "42", HtmlSafeString.new.cast(42)
        assert_nil HtmlSafeString.new.cast(nil)
      end

      def test_reports_string_for_introspection
        assert_equal :string, HtmlSafeString.new.type
      end

      def test_is_not_registered_as_an_active_model_type
        assert_instance_of ActiveModel::Type::String, ActiveModel::Type.lookup(:string)
      end
    end
  end
end
