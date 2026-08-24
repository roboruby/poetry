# frozen_string_literal: true

module Poetry
  module Ui
    # Client-side toast delivery.
    module ToastTrigger
      # A button that shows a toast without a server round-trip: on press
      # the toaster stamps a clone of an addressed <template>'s toast
      # into its region. The template holds one fully rendered
      # poetry_toast - exactly what a Turbo Stream would append - so the
      # visible limit, queueing, and stacking behave the same on either
      # path. For purely client-side moments: copied, undone, queued.
      #
      # @example
      #   <%= render Poetry::Ui::ToastTrigger::Component.new(template: "copied-toast") do %>
      #     Copy link
      #   <% end %>
      #   <template id="copied-toast">
      #     <%= poetry_toast(duration: 4000) do |toast| %>
      #       <% toast.with_title { "Copied" } %>
      #     <% end %>
      #   </template>
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
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

        # The id of the <template> element holding the rendered toast to stamp.
        option :template, :string, required: true
        # Scopes the stamp to one toaster region id on multi-toaster pages;
        # omit for the page's toaster.
        option :toaster, :string
        # The Button variant the trigger renders at.
        option :variant, :symbol, default: :outline
        # The Button size the trigger renders at.
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

        # @api private
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
