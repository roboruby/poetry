# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Stimulus
      class BuilderTest < Minitest::Test
        def test_format_identifier_single
          assert_equal "my-controller", Builder.format_identifier(:my_controller)
        end

        def test_format_identifier_namespaced
          assert_equal "admin--dropdown", Builder.format_identifier(%i[admin dropdown])
        end

        def test_action_with_event
          builder = Builder.new("dropdown", HTML::Attributes.new)

          assert_equal "click->dropdown#toggle", builder.action(:toggle, on: :click)
        end

        def test_action_without_event_returns_controller_method
          builder = Builder.new("dropdown", HTML::Attributes.new)

          assert_equal "dropdown#toggle", builder.action(:toggle)
        end

        def test_register_controller_sets_data_controller
          attrs = HTML::Attributes.new
          Builder.new("dropdown", attrs).register_controller

          assert_equal "dropdown", attrs.to_attributes["data-controller"]
        end
      end
    end
  end
end
