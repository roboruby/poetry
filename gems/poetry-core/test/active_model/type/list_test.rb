# frozen_string_literal: true

require "test_helper"

module ActiveModel
  module Type
    class ListTest < ActiveSupport::TestCase
      def test_reports_list_for_introspection
        assert_equal :list, List.new.type
      end

      def test_registered_as_active_model_type
        assert_instance_of List, ActiveModel::Type.lookup(:list)
      end

      def test_casts_scalars_and_arrays_to_string_arrays
        type = List.new

        assert_equal [], type.cast(nil)
        assert_equal %w[shipping], type.cast(:shipping)
        assert_equal %w[a b], type.cast([:a, "b"])
      end
    end
  end
end
