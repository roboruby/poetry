# frozen_string_literal: true

module Poetry
  module Ui
    module Switch
      # The Switch preview matrix: both sizes x both states x disabled,
      # the Field-bound recipe, and the RTL thumb-travel fix (the poetry
      # addition over shadcn's LTR-only translate).
      class Preview < Poetry::Core::Preview::Base
        # @!group States

        def default
          render_component(name: "airplane_mode", label: "Airplane mode")
        end

        def checked
          render_component(name: "airplane_mode", checked: true, label: "Airplane mode")
        end

        def disabled
          render_component(name: "airplane_mode", disabled: true, label: "Airplane mode")
        end

        def disabled_checked
          render_component(name: "airplane_mode", checked: true, disabled: true, label: "Locked on")
        end

        # @!endgroup

        # @!group Sizes

        # size: :sm for dense settings lists - the thumb derives its size
        # via group-data-[size=sm]/switch (no per-element size classes).
        def small
          render_component(name: "compact", size: :sm, checked: true, label: "Compact density")
        end

        # @!endgroup

        # @!group Recipes

        # Field-bound: control_attributes land on the BUTTON (the label-for
        # target).
        def in_a_field
          field = Field::Component.new(
            id: "preview-notifications", label_text: "Notifications",
            hint: "Applied the moment it flips."
          )
          render_component(field) do
            embed(Component.new(name: "notifications", checked: true,
                                **field.control_attributes.transform_keys(&:to_sym)))
          end
        end

        # The RTL travel fix: the knob still moves toward the "on" end
        # (rtl:data-[state=checked]:-translate-x-... - a poetry addition;
        # shadcn's translate is physical/LTR-only).
        def rtl
          render_component(name: "rtl_demo", checked: true, label: "وضع الطيران", dir: "rtl")
        end

        # @!endgroup
      end
    end
  end
end
