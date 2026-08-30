# frozen_string_literal: true

module Poetry
  module Core
    module Preview
      # Provides functionality to mark preview classes as abstract and exclude them from the preview index.
      # Adapted from an MIT-licensed source (source and license in
      # THIRD_PARTY_NOTICES.md).
      #
      # This module adds an `abstract_class` accessor to preview classes and automatically filters
      # them out when listing all available previews. This is particularly useful for creating base
      # preview classes that provide shared functionality but shouldn't appear in the preview UI.
      #
      # The module works by extending preview classes (typically ViewComponent::Preview) and prepending
      # class methods that add the abstract_class attribute and modify the `all` method to exclude
      # abstract previews from the results.
      #
      # @example Marking a base preview class as abstract
      #   class ApplicationPreview < ViewComponent::Preview
      #     extend Poetry::Core::Preview::Abstract
      #     self.abstract_class = true
      #
      #     # Shared helper methods for all previews
      #     def render_in_container(&block)
      #       content_tag(:div, class: "preview-container", &block)
      #     end
      #   end
      #
      #   class ButtonPreview < ApplicationPreview
      #     # This will appear in the preview index
      #     def default
      #       render ButtonComponent.new
      #     end
      #   end
      #
      #   ViewComponent::Preview.all
      #   # => [ButtonPreview] (ApplicationPreview is excluded)
      #
      # @example Using with Poetry::Core::Preview::Base
      #   # Poetry::Core::Preview::Base automatically uses this module
      #   class MyBasePreview < Poetry::Core::Preview::Base
      #     self.abstract_class = true
      #
      #     def helper_method
      #       "shared logic"
      #     end
      #   end
      #
      #   class ConcretePreview < MyBasePreview
      #     def example
      #       render SomeComponent.new
      #     end
      #   end
      #
      # @example Checking if a preview is abstract
      #   ApplicationPreview.abstract_class?  # => true
      #   ButtonPreview.abstract_class?       # => false (or nil)
      #
      # @note This module is automatically applied to ViewComponent::Preview when Poetry::Core::Preview::Base
      #   is loaded, so abstract_class functionality is available throughout the preview system.
      #
      module Abstract
        # Hook method called when this module is extended into a class.
        #
        # Prepends ClassMethods to the class's singleton class, making the abstract_class
        # functionality available to the extending class and overriding its `all` method.
        #
        # @param base [Class] the class being extended with this module
        # @return [void]
        # @api private
        def self.extended(base)
          base.singleton_class.prepend(ClassMethods)
        end

        # Class methods added to preview classes that extend the Abstract module.
        #
        # These methods provide the abstract_class attribute and modify preview collection
        # behavior to automatically filter out abstract classes.
        module ClassMethods
          # @!attribute [rw] abstract_class
          #   @return [Boolean, nil] whether this preview class is abstract
          attr_accessor :abstract_class

          # Checks if this preview class is marked as abstract.
          #
          # @return [Boolean, nil] true if abstract, false or nil otherwise
          # @example
          #   MyPreview.abstract_class = true
          #   MyPreview.abstract_class?  # => true
          alias abstract_class? abstract_class

          # Returns all non-abstract descendant preview classes.
          #
          # This method overrides the default ViewComponent::Preview.all to exclude
          # any preview classes marked as abstract. It ensures previews are loaded
          # before filtering if no descendants exist yet.
          #
          # @return [Array<Class>] array of non-abstract preview classes
          # @example
          #   class BasePreview < ViewComponent::Preview
          #     extend Poetry::Core::Preview::Abstract
          #     self.abstract_class = true
          #   end
          #
          #   class ButtonPreview < BasePreview; end
          #   class CardPreview < BasePreview; end
          #
          #   ViewComponent::Preview.all
          #   # => [ButtonPreview, CardPreview] (BasePreview excluded)
          def all
            load_previews if descendants.reject(&:abstract_class?).empty?
            descendants.reject(&:abstract_class?)
          end
        end
      end
    end
  end
end
