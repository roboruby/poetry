# frozen_string_literal: true

module Poetry
  module Ui
    # The optimistic-form builder (the hotwire_club-toolbox port):
    # renders the scaffolding poetry_optimistic_form's controller consumes -
    # <template> targets holding the PREDICTED state as turbo-stream(s)
    # (the same vocabulary the server answers in, so prediction and truth
    # never need bespoke DOM patching), and the hidden field carrying the
    # submitted value.
    class OptimisticFormBuilder < ActionView::Helpers::FormBuilder
      # Distinguishes "no value given" from a real nil/false - a favorite
      # toggle legitimately submits false, so false must survive.
      UNSET = Object.new

      # The predicted state, cloned into the DOM on submit. Positional form
      # wraps a turbo_stream update for you; block form authors the
      # stream(s) directly (several regions, other actions):
      #
      #   form.optimistic_template dom_id(photo, "fav"), icon(!photo.favorite)
      #   form.optimistic_template { turbo_stream.update("cart-count") { @count + 1 } }
      def optimistic_template(target = nil, template = nil, &block)
        content = if block
                    @template.capture(&block)
                  else
                    # The <turbo-stream> element built directly (its contract:
                    # payload inside an inner <template>) - no turbo-rails
                    # helper needed in the rendering context.
                    @template.content_tag(
                      "turbo-stream",
                      @template.content_tag(:template, template),
                      action: "update", target: target
                    )
                  end

        @template.content_tag(
          :template,
          content,
          data: { "poetry--core--optimistic-form-target" => "template" }
        )
      end

      # Explicit placement of the submitted-value field; calling it
      # suppresses the helper's automatic injection.
      def optimistic_hidden_field(attribute_name, value:)
        @optimistic_hidden_field_rendered = true
        hidden_field(attribute_name, value: value)
      end

      def optimistic_hidden_field_rendered?
        !!@optimistic_hidden_field_rendered
      end
    end
  end
end
