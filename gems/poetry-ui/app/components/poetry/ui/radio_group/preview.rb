# frozen_string_literal: true

module Poetry
  module Ui
    module RadioGroup
      # The RadioGroup preview matrix: group configs (none-checked,
      # one-checked, required, disabled) x item states (checked, disabled,
      # invalid), the radio-group-demo port, and the horizontal-layout
      # recipe (caller classes; the keyboard stays both-axis).
      class Preview < Poetry::Core::Preview::Base
        # @!group States

        # The radio-group-demo port: value pre-checked, items paired with
        # Labels via item label:.
        def default
          render_component(name: "density", value: "comfortable", label: "Density") do |group|
            group.with_item(value: "default", label: "Default")
            group.with_item(value: "comfortable", label: "Comfortable")
            group.with_item(value: "compact", label: "Compact")
          end
        end

        # Nothing checked (pre-selection): Tab lands on the FIRST enabled
        # item; nothing submits until the user chooses (presence
        # validation stays honest).
        def none_checked
          render_component(name: "plan", label: "Plan") do |group|
            group.with_item(value: "monthly", label: "Monthly")
            group.with_item(value: "yearly", label: "Yearly")
          end
        end

        # A disabled option mid-list: skipped by Tab AND filtered from the
        # arrow collection.
        def disabled_item
          render_component(name: "tier", value: "free", label: "Tier") do |group|
            group.with_item(value: "free", label: "Free")
            group.with_item(value: "pro", label: "Pro (unavailable)", disabled: true)
            group.with_item(value: "enterprise", label: "Enterprise")
          end
        end

        # Root-level disabled: a locked-in choice still renders its dot
        # (and still submits - hidden radios disable too, so it does NOT).
        def disabled_group
          render_component(name: "plan", value: "yearly", disabled: true, label: "Plan") do |group|
            group.with_item(value: "monthly", label: "Monthly")
            group.with_item(value: "yearly", label: "Yearly")
          end
        end

        # The field-level error treatment: aria-invalid on every item (the
        # destructive ring), wired by Field/FormBuilder upstream.
        def invalid
          render_component(name: "plan", invalid: true, required: true, label: "Plan") do |group|
            group.with_item(value: "monthly", label: "Monthly")
            group.with_item(value: "yearly", label: "Yearly")
          end
        end

        # The choice-card items (variant: :card): title + description
        # inside a selectable bordered label - the whole card toggles the
        # radio (the upstream Choice Card recipe).
        def choice_cards
          render_component(name: "compute", value: "kubernetes", label: "Compute environment",
                           class: "w-80") do |group|
            group.with_item(value: "kubernetes", label: "Kubernetes", variant: :card,
                            description: "Run GPU workloads on a K8s cluster.")
            group.with_item(value: "vm", label: "Virtual Machine", variant: :card,
                            description: "Access a cluster to run GPU workloads.")
          end
        end

        # @!endgroup

        # @!group Recipes

        # Horizontal layout is a CALLER class (source has no orientation
        # styling); the keyboard stays both-axis.
        def horizontal_layout
          render_component(name: "align", value: "left", label: "Alignment", class: "grid-flow-col") do |group|
            group.with_item(value: "left", label: "Left")
            group.with_item(value: "center", label: "Center")
            group.with_item(value: "right", label: "Right")
          end
        end

        # Field-bound (the FormBuilder shape): the group takes the Field's
        # id + describedby; the hint reads on the ROOT (group-level).
        def in_a_field
          field = Field::Component.new(
            id: "preview-plan", label_text: "Plan",
            hint: "You can change this anytime.", required: true
          )
          render_component(field) do
            embed(Component.new(name: "plan", value: "monthly", required: true, label: "Plan",
                                id: "preview-plan",
                                "aria-describedby": "preview-plan-hint")) do |group|
              group.with_item(value: "monthly", label: "Monthly")
              group.with_item(value: "yearly", label: "Yearly")
            end
          end
        end

        # @!endgroup
      end
    end
  end
end
