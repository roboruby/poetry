# frozen_string_literal: true

module Poetry
  module Ui
    module FieldGroup
      # Upstream FieldGroup structure: the named group/@container pair is
      # what responsive fields and theme rhythm rules key on. The stack
      # gap is design and rides the theme under cn-field-group; :choices
      # emits its marker for the tighter checkbox-run rhythm (upstream
      # overrides data-slot to checkbox-group for the same effect - poetry
      # keeps the slot stable and mirrors the variant as a class, the
      # drawer-direction marker pattern).
      class Style < Poetry::Core::Style
        base "cn-field-group group/field-group @container/field-group flex w-full flex-col"

        # Default is the base state and emits nothing (the marker/core-X
        # empty-variant precedent).
        variant :variant, {
          default: "",
          choices: "cn-field-group-choices"
        }
      end
    end
  end
end
