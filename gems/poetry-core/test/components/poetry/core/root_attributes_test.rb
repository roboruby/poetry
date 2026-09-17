# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # The root and element attribute builders every component's markup rides on.
    class RootAttributesTest < Minitest::Test
      class PlainComponent < Poetry::Core::Component
        def css = "plain-base"
      end

      class WiredComponent < Poetry::Core::Component
        use_stimulus do
          on :root do
            controller(:accordion) { register }
          end
          on :panel do
            controller(:accordion) { register }
          end
        end

        def css = "wired-base"

        def root_attributes
          super("role" => "region", "data-open" => "")
        end
      end

      class RenamedComponent < Poetry::Core::Component
        def css = "renamed-base"

        def root_attributes
          super("data-slot" => "renamed-shell")
        end
      end

      def test_the_default_root_carries_slot_and_component_identity
        attrs = PlainComponent.new.root_attributes.to_attributes

        assert_equal "plain-base", attrs["class"]
        assert_equal PlainComponent.component_title.to_s.tr("_", "-"), attrs["data-slot"]
        assert_equal PlainComponent.component_title.to_s, attrs["data-component"]
      end

      def test_the_root_slot_is_the_title_in_kebab_form
        assert_equal PlainComponent.component_title.to_s.tr("_", "-"), PlainComponent.new.root_slot
      end

      def test_the_caller_wins_and_the_component_fills_the_gaps
        attrs = PlainComponent.new(class: "mine", id: "given", data: { slot: "custom" }).root_attributes.to_attributes

        assert_equal "given", attrs["id"]
        assert_equal "custom", attrs["data-slot"]
        assert_includes attrs["class"], "plain-base"
        assert_includes attrs["class"], "mine"
      end

      def test_an_override_passes_its_markup_up
        attrs = WiredComponent.new.root_attributes.to_attributes

        assert_equal "region", attrs["role"]
        assert_equal "", attrs["data-open"]
        assert_equal WiredComponent.component_title.to_s, attrs["data-component"]
      end

      def test_a_slot_passed_up_replaces_the_default
        assert_equal "renamed-shell", RenamedComponent.new.root_attributes.to_attributes["data-slot"]
      end

      def test_a_declared_root_is_wired_by_default
        assert_match(/accordion\z/, WiredComponent.new.root_attributes.to_attributes["data-controller"])
      end

      def test_an_undeclared_root_stays_unwired
        refute_includes PlainComponent.new.root_attributes.to_attributes.keys, "data-controller"
      end

      def test_element_attributes_merge_a_declared_elements_wiring
        attrs = WiredComponent.new.element_attributes({ "id" => "panel-1", "role" => "region" }, stimulus: :panel)

        assert_kind_of Poetry::Core::HTML::Attributes, attrs
        assert_match(/accordion\z/, attrs.to_attributes["data-controller"])
        assert_equal "panel-1", attrs.to_attributes["id"]
      end

      def test_element_attributes_concatenate_wiring_instead_of_clobbering_it
        attrs = WiredComponent.new.element_attributes({ "data-controller" => "mine" }, stimulus: :panel)

        assert_match(/\Amine .*accordion\z/, attrs.to_attributes["data-controller"])
      end

      def test_element_attributes_without_wiring_are_the_markup
        attrs = PlainComponent.new.element_attributes({ "id" => "x", "hidden" => true })

        assert_equal({ "id" => "x", "hidden" => "hidden" }, attrs.to_attributes)
      end

      def test_element_attributes_raise_for_an_undeclared_element
        assert_raises(ArgumentError) { PlainComponent.new.element_attributes({}, stimulus: :nowhere) }
      end
    end
  end
end
