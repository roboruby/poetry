# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class RequiresAnyTest < Minitest::Test
      def test_phrases_the_block_slots_and_options_in_that_order
        group = { "content" => true, "slots" => %w[leading trailing], "options" => %w[label icon],
                  "hint" => "something visible" }

        assert_equal "one of a content block / with_leading / with_trailing / label: / icon: (something visible)",
                     RequiresAny.phrase(group)
      end

      def test_omits_the_parts_a_group_does_not_name
        assert_equal "one of label: (a name)", RequiresAny.phrase("options" => ["label"], "hint" => "a name")
        assert_equal "one of a content block (text)", RequiresAny.phrase("content" => true, "hint" => "text")
      end
    end
  end
end
