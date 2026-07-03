# frozen_string_literal: true

module Poetry
  module Ui
    module Checkbox
      # The Checkbox preview matrix: all three check-states x disabled x
      # invalid, the Field-bound recipe, and the disabled+checked footgun
      # (disabled fields don't submit - a checked box that submits nothing).
      class Preview < Poetry::Core::Preview::Base
        # @!group States

        def default
          render_component(name: "terms", label: "Accept terms and conditions")
        end

        def checked
          render_component(name: "terms", checked: true, label: "Accept terms and conditions")
        end

        # Server/programmatic only - the select-all parent over a partial
        # selection. Announces as "mixed"; the first toggle resolves to
        # checked (Radix-exact).
        def indeterminate
          render_component(name: "select_all", checked: :indeterminate, label: "Select all rows")
        end

        def disabled
          render_component(name: "terms", disabled: true, label: "Accept terms and conditions")
        end

        # The footgun preview: disabled inputs DON'T submit - a disabled
        # checked checkbox submits nothing, not "1".
        def disabled_checked
          render_component(name: "terms", checked: true, disabled: true, label: "Locked on (submits nothing)")
        end

        def invalid
          render_component(name: "terms", label: "Accept terms and conditions", "aria-invalid": true)
        end

        # @!endgroup

        # @!group Recipes

        # Field-bound: control_attributes land the id (the label-for
        # target), aria-describedby, and aria-required on the BUTTON.
        def in_a_field
          field = Field::Component.new(
            id: "preview-newsletter", label_text: "Email newsletter",
            hint: "Sent weekly. Unsubscribe anytime.", required: true
          )
          render_component(field) do
            embed(Component.new(name: "newsletter", checked: true,
                                **field.control_attributes.transform_keys(&:to_sym)))
          end
        end

        # Visual-only mode (no name:) - controlled UI like DataTable row
        # selection; state lives on data-state alone (discouraged in forms).
        def visual_only
          render_component(checked: true, label: "Row selected")
        end

        # @!endgroup
      end
    end
  end
end
