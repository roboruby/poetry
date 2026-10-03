# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # A host that subclasses a gem component without a Style sidecar of
    # its own gets the parent's dictionary, for every component the gem
    # ships: a bare subclass never renders unstyled.
    class BareSubclassTest < ViewComponent::TestCase
      # The named subclasses the test defines (a dictionary lookup needs a
      # class name: Acme::Badge2 -> Acme::Badge2::Style, which is absent).
      module Acme
      end

      def test_every_bare_subclass_of_a_gem_component_keeps_the_parent_dictionary
        unstyled = registry_components.filter_map do |component|
          parent = component.style_class
          next unless parent

          subclass = bare_subclass_of(component)
          subclass.name unless subclass.style_class.equal?(parent)
        end

        assert_empty unstyled, "bare subclasses with no dictionary:\n#{unstyled.join("\n")}"
      end

      def test_a_bare_subclass_renders_the_parent_root_classes
        parent = render_inline(Badge::Component.new(variant: :secondary)) { "x" }
        child = render_inline(bare_subclass_of(Badge::Component).new(variant: :secondary)) { "x" }

        parent_class = parent.css("[data-slot=badge]").first["class"]

        assert_predicate parent_class, :present?
        assert_equal parent_class, child.css("[data-slot=badge]").first["class"]
      end

      private

      def registry_components
        Poetry::Core::Registry.new(source_root: Poetry::Ui.root).components
      end

      # Acme::<Component path joined>, defined once per component.
      def bare_subclass_of(component)
        name = component.name.delete_prefix("Poetry::Ui::").delete_suffix("::Component").gsub("::", "")
        return Acme.const_get(name, false) if Acme.const_defined?(name, false)

        Acme.const_set(name, Class.new(component))
      end
    end
  end
end
