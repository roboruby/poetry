# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module NumberField
      class ComponentTest < ViewComponent::TestCase
        CURRENCY = { style: "currency", currency: "USD" }.freeze

        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def test_the_display_format_reaches_the_controller_as_json
          fragment = doc(render_inline(Component.new(name: "price", format: CURRENCY)).to_html)
          root = fragment.css('[data-controller~="poetry--core--number-field"]').first

          assert_equal CURRENCY.to_json, root["data-poetry--core--number-field-format-value"]
          assert_equal "decimal", fragment.css("input[inputmode]").first["inputmode"]
        end

        # Rails asks what it renders for `format` and reads the answer as
        # the format of the template. A render that goes through the
        # renderer asks, and from Rails 8.2 a render in a view does too, so
        # the option's Hash is never what the component answers with.
        def test_a_display_format_renders_through_the_renderer
          component = Component.new(name: "price", format: CURRENCY)

          html = vc_test_controller.view_context.render(renderable: component)

          assert_includes html, "data-poetry--core--number-field-format-value"
          assert_nil component.format
          assert_equal CURRENCY.stringify_keys, component.number_format
        end

        def test_a_format_that_is_not_a_hash_is_refused
          error = assert_raises(ArgumentError) do
            render_inline(Component.new(name: "price", format: "currency"))
          end

          assert_match(/format: takes an Intl\.NumberFormatOptions Hash/, error.message)
        end
      end
    end
  end
end
