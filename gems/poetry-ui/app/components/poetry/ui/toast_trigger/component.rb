# frozen_string_literal: true

module Poetry
  module Ui
    module ToastTrigger
      # The client-side toast delivery trigger (the no-round-trip path -
      # what sonner does with a toast() JS factory, done with
      # server-rendered markup): press -> the toaster clones the addressed
      # <template>'s toast into its region. The toast inside the template
      # is byte-for-byte what a Turbo Stream would append; the toaster's
      # childList observer reconciles limit + reflow like any other path.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "template: names a <template> element id holding ONE rendered poetry_toast - " \
          "the trigger stamps a clone into the toaster on press.",
          "toaster: scopes the stamp to one region id on multi-toaster pages; omit it for " \
          "the page's toaster.",
          "Give the templated toast a duration (auto-dismiss) - repeated presses stack " \
          "persistent toasts.",
          "Server round-trips keep using turbo_stream.poetry_toast - this trigger is for " \
          "purely client-side moments (copied, undone, queued)."
        ].freeze

        use_stimulus do
          on :root do
            controller :"toast-trigger" do
              register
              value :template
              value :toaster, if: -> { toaster.present? }
              action :fire, on: :click
            end
          end
        end

        option :template, :string, required: true
        option :toaster, :string
        option :variant, :symbol, default: :outline
        option :size, :symbol, default: :default

        part "toast-trigger", "The stamping button - press clones the template's toast " \
                              "into the toaster region",
             states: {
               "data-variant" => "always - the Button variant the trigger renders at",
               "data-size" => "always - the Button size the trigger renders at"
             }
        # The trigger IS a poetry Button (no wrapper element), so Button's
        # inner anatomy lands in this component's data-component scope.
        part "label", "The Button's label span (the trigger renders AS a poetry Button)"

        def button_options
          wiring = { data: { slot: "toast-trigger" } }
                   .merge(stimulus_attributes_for(:root))
                   .merge(component_data_attributes)

          # Caller attributes never clobber the trigger's wiring: both sides
          # flow through Attributes, so a host data-controller/action
          # concatenates instead of silently killing fire-on-click.
          { variant: variant, size: size }
            .merge(Poetry::Core::HTML::Attributes.merged(wiring, html_attributes))
            .symbolize_keys
        end
      end
    end
  end
end
