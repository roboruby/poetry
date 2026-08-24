# frozen_string_literal: true

module Poetry
  module Ui
    # Family identity, derived from the includer's namespace
    # (Poetry::Ui::HoverCard::Component -> "HoverCard" / "hover-card"):
    # the data-slot prefix, error nouns, and sibling constants (the Style
    # dictionary) all resolve through it, so shared kernels never
    # hard-code a family. Carries the two identity surfaces every overlay
    # family re-typed: the root shell and the instance-id seed. A family
    # with a different root (the menu roots stamp dir) or a different id
    # shape (Menus::Sub) simply overrides.
    module FamilyIdentity
      def root_attributes
        html_attributes.merge_if_not_set(
          { "data-slot" => family_slot_prefix }
            .merge(stimulus_attributes_for(:root))
            .merge(component_data_attributes)
        )
      end

      private

      def family_namespace
        self.class.module_parent
      end

      def family_name
        @family_name ||= family_namespace.name.demodulize
      end

      def family_slot_prefix
        @family_slot_prefix ||= family_name.underscore.dasherize
      end

      def family_style
        family_namespace::Style
      end

      # Server-stable unique id seed (two of a family on one page must
      # not share ids); portal-safe by convention - controllers resolve
      # content via the id pair, never a Stimulus target.
      def instance_id
        @instance_id ||= poetry_instance_id("poetry-#{family_slot_prefix}")
      end
    end
  end
end
