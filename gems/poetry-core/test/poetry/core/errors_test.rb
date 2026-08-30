# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # The error surface: the Error base class every poetry error descends
    # from, and IconNotFound - the icon-set contract's rescue point
    # (FileSet#fetch raises it; the Icon component's missing-icon policy
    # rescues exactly it).
    class ErrorsTest < Minitest::Test
      def test_error_inherits_from_standard_error
        assert_operator Poetry::Core::Error, :<, StandardError
      end

      def test_error_carries_a_custom_message
        error = assert_raises(Poetry::Core::Error) do
          raise Poetry::Core::Error, "Custom error message"
        end

        assert_equal "Custom error message", error.message
      end

      def test_error_can_be_rescued_as_standard_error
        raise Poetry::Core::Error, "Test error"
      rescue StandardError => e
        assert_instance_of Poetry::Core::Error, e
      end

      def test_icon_not_found_inherits_from_error
        assert_operator Poetry::Core::IconNotFound, :<, Poetry::Core::Error
      end

      def test_icon_not_found_carries_message_name_and_suggestion
        error = Poetry::Core::IconNotFound.new(
          %(unknown icon :"alert-circle" (not in this set) - did you mean :"circle-alert"?),
          name: :"alert-circle", suggestion: "circle-alert"
        )

        assert_includes error.message, "did you mean"
        assert_equal :"alert-circle", error.name
        assert_equal "circle-alert", error.suggestion
      end

      def test_icon_not_found_suggestion_defaults_to_nil
        error = Poetry::Core::IconNotFound.new("invalid icon name \"../x\"", name: "../x")

        assert_equal "../x", error.name
        assert_nil error.suggestion
      end

      def test_icon_not_found_attributes_are_read_only
        error = Poetry::Core::IconNotFound.new("unknown icon :x", name: :x)

        refute_respond_to error, :name=
        refute_respond_to error, :suggestion=
      end

      def test_icon_not_found_can_be_rescued_as_error_and_standard_error
        raise Poetry::Core::IconNotFound.new("unknown icon :x", name: :x)
      rescue Poetry::Core::Error => e
        assert_instance_of Poetry::Core::IconNotFound, e
        assert_kind_of StandardError, e
        assert_equal :x, e.name
      end
    end
  end
end
