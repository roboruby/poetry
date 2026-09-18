# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # The root and part attribute builders every component's markup rides on.
    class RootAttributesTest < Minitest::Test
      class PlainComponent < Poetry::Core::Component
        def css(element = nil, **) = element ? nil : "plain-base"
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

        def css(element = nil, **) = element ? "wired-#{element}" : "wired-base"

        def root_attributes
          super("role" => "region", "data-open" => "")
        end
      end

      class RenamedComponent < Poetry::Core::Component
        def css(element = nil, **) = element ? nil : "renamed-base"

        def root_attributes
          super("data-slot" => "renamed-shell")
        end
      end

      def test_the_default_root_carries_slot_and_component_identity
        attrs = PlainComponent.new.root_attributes

        assert_kind_of Hash, attrs
        assert_equal "plain-base", attrs["class"]
        assert_equal PlainComponent.component_title.to_s.tr("_", "-"), attrs["data-slot"]
        assert_equal PlainComponent.component_title.to_s, attrs["data-component"]
      end

      def test_the_root_slot_is_the_title_in_kebab_form
        assert_equal PlainComponent.component_title.to_s.tr("_", "-"), PlainComponent.new.root_slot
      end

      def test_the_caller_wins_and_the_component_fills_the_gaps
        attrs = PlainComponent.new(class: "mine", id: "given", data: { slot: "custom" }).root_attributes

        assert_equal "given", attrs["id"]
        assert_equal "custom", attrs["data-slot"]
        assert_includes attrs["class"], "plain-base"
        assert_includes attrs["class"], "mine"
      end

      def test_an_override_passes_its_markup_up
        attrs = WiredComponent.new.root_attributes

        assert_equal "region", attrs["role"]
        assert_equal "", attrs["data-open"]
        assert_equal WiredComponent.component_title.to_s, attrs["data-component"]
      end

      def test_a_slot_passed_up_replaces_the_default
        assert_equal "renamed-shell", RenamedComponent.new.root_attributes["data-slot"]
      end

      def test_a_declared_root_is_wired_by_default
        assert_match(/accordion\z/, WiredComponent.new.root_attributes["data-controller"])
      end

      def test_an_undeclared_root_stays_unwired
        refute_includes PlainComponent.new.root_attributes.keys, "data-controller"
      end

      def test_the_root_is_flat_and_ready_to_splat
        attrs = PlainComponent.new(data: { state: "open" }, aria: { label: "Plain" }, disabled: true).root_attributes

        assert_equal "open", attrs["data-state"]
        assert_equal "Plain", attrs["aria-label"]
        assert_equal "disabled", attrs["disabled"]
      end

      def test_a_part_carries_its_slot_classes_and_wiring
        attrs = WiredComponent.new.element_attributes(:panel, { "id" => "panel-1", "role" => "region" })
        root = WiredComponent.new.root_slot

        assert_equal "#{root}-panel", attrs["data-slot"]
        assert_equal "wired-panel", attrs["class"]
        assert_match(/accordion\z/, attrs["data-controller"])
        assert_equal "panel-1", attrs["id"]
      end

      def test_a_parts_markup_overrides_the_stamped_slot_and_classes
        attrs = WiredComponent.new.element_attributes(:panel, { "data-slot" => "custom-panel", "class" => "mine" })

        assert_equal "custom-panel", attrs["data-slot"]
        assert_equal "mine", attrs["class"]
      end

      def test_a_part_without_a_dictionary_element_carries_no_class
        attrs = PlainComponent.new.element_attributes(:panel, { "id" => "p" })

        refute_includes attrs.keys, "class"
        assert_equal "#{PlainComponent.new.root_slot}-panel", attrs["data-slot"]
      end

      def test_an_undeclared_part_stays_unwired_and_stimulus_names_another_element
        component = WiredComponent.new

        refute_includes component.element_attributes(:label, { "id" => "l" }).keys, "data-controller"
        assert_match(/accordion\z/,
                     component.element_attributes(:label, { "id" => "l" }, stimulus: :panel)["data-controller"])
      end

      def test_stimulus_false_leaves_a_declared_part_unwired
        refute_includes WiredComponent.new.element_attributes(:panel, {}, stimulus: false).keys, "data-controller"
      end

      def test_a_part_with_underscores_slots_in_kebab_form
        attrs = PlainComponent.new.element_attributes(:chip_input, {})

        assert_equal "#{PlainComponent.new.root_slot}-chip-input", attrs["data-slot"]
      end

      def test_markup_without_a_part_is_the_markup_with_its_wiring
        attrs = WiredComponent.new.element_attributes({ "id" => "x", "hidden" => true }, stimulus: :panel)

        assert_equal "x", attrs["id"]
        assert_equal "hidden", attrs["hidden"]
        assert_match(/accordion\z/, attrs["data-controller"])
        refute_includes attrs.keys, "data-slot"
      end

      def test_element_attributes_concatenate_wiring_instead_of_clobbering_it
        attrs = WiredComponent.new.element_attributes({ "data-controller" => "mine" }, stimulus: :panel)

        assert_match(/\Amine .*accordion\z/, attrs["data-controller"])
      end

      def test_element_attributes_raise_for_an_undeclared_element
        assert_raises(ArgumentError) { PlainComponent.new.element_attributes({}, stimulus: :nowhere) }
      end
    end
  end
end
