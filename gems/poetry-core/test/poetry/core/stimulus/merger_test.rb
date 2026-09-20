# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Stimulus
      class MergerTest < Minitest::Test
        def setup
          @merger = Merger.new
        end

        def test_merge_controllers_deduplicates
          assert_equal "dropdown modal tooltip",
                       @merger.merge_controllers("dropdown modal", "dropdown tooltip")
        end

        def test_merge_controllers_ignores_blank
          assert_equal "dropdown", @merger.merge_controllers("dropdown", nil, "")
        end

        def test_merge_actions_deduplicates_preserving_order
          assert_equal "click->modal#open keyup->form#validate",
                       @merger.merge_actions("click->modal#open", "click->modal#open", "keyup->form#validate")
        end
      end
    end
  end
end
