# frozen_string_literal: true

module Poetry
  module Ui
    module Field
      # The Field preview matrix - the label/control/hint/error quartet with
      # the control wired through control_attributes (the aria plumbing the
      # component exists to own). Rendering rides the sidecar preview.html.erb:
      # nesting a control inside the field needs a real view context, and
      # Preview#render inside a content block is the render_args DSL, not
      # ActionView's render.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_with(component: Component.new(id: "field-email", label_text: "Email"),
                      input_options: { type: "email", name: "email" })
        end

        def with_hint
          render_with(component: Component.new(id: "field-handle", label_text: "Handle",
                                               hint: "Public, letters and dashes only."),
                      input_options: { name: "handle" })
        end

        def with_error
          render_with(component: Component.new(id: "field-work-email", label_text: "Work email",
                                               hint: "We never share it.", error: "can't be blank",
                                               required: true),
                      input_options: { type: "email", name: "work_email" })
        end

        # The boolean-control layout: control left, label + hint stacked
        # right, box centered on the label line (the checkbox/switch field
        # pattern upstream demos with orientation=horizontal).
        def horizontal_with_checkbox
          render_with(component: Component.new(id: "field-newsletter", label_text: "Email newsletter",
                                               hint: "Sent weekly. Unsubscribe anytime.",
                                               orientation: :horizontal),
                      checkbox_options: { name: "newsletter", checked: true })
        end
      end
    end
  end
end
