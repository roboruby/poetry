# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Textarea
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_textarea(**)
          doc(render_inline(Component.new(**)).to_html)
        end

        def test_the_native_textarea_renders_with_the_self_id_and_no_js
          textarea = render_textarea(name: "bio").css("textarea").first

          assert_equal "textarea", textarea["data-slot"]
          assert_equal "textarea", textarea["data-component"]
          assert_equal "bio", textarea["name"]
          assert_nil textarea["data-controller"], "ZERO JS - auto-grow is CSS"
        end

        def test_the_value_renders_as_element_content
          textarea = render_textarea(name: "bio", value: "Line one.\nLine two.").css("textarea").first

          assert_equal "Line one.\nLine two.", textarea.text
          assert_nil textarea["value"], "textarea semantics: content, not a value attribute"
        end

        def test_the_closing_tag_breakout_escapes
          html = render_inline(Component.new(name: "bio", value: %(</textarea><script>x()</script>))).to_html

          refute_includes html, "<script>", "the textarea injection surface is the </textarea> breakout"
          assert_includes html, "&lt;/textarea&gt;"
          assert_equal %(</textarea><script>x()</script>),
                       doc(html).css("textarea").first.text, "round-trips as plain text"
        end

        def test_placeholder_rows_and_disabled_render_as_attributes
          textarea = render_textarea(name: "bio", placeholder: "Tell us", rows: 8, disabled: true)
                     .css("textarea").first

          assert_equal "Tell us", textarea["placeholder"]
          assert_equal "8", textarea["rows"]
          assert textarea.key?("disabled")
        end

        def test_invalid_renders_aria_invalid
          textarea = render_textarea(name: "bio", invalid: true).css("textarea").first

          assert_equal "true", textarea["aria-invalid"]
        end

        def test_field_control_attributes_land_error_before_hint
          field = Field::Component.new(id: "report", label_text: "Report",
                                       hint: "Markdown ok.", error: "can't be blank", required: true)
          textarea = render_textarea(name: "report",
                                     **field.control_attributes.transform_keys(&:to_sym))
                     .css("textarea").first

          assert_equal "report", textarea["id"]
          assert_equal "report-error report-hint", textarea["aria-describedby"]
          assert_equal "true", textarea["aria-invalid"]
          assert_equal "true", textarea["aria-required"]
          refute textarea.key?("required"), "never native required (the Field family rule)"
        end

        def test_the_source_exact_class_string_lands
          textarea = render_textarea(name: "bio").css("textarea").first

          # Placeholder color rides the theme (rhea darkens it
          # on tinted surfaces to hold AA - inline would beat every theme).
          %w[cn-textarea field-sizing-content min-h-16 w-full].each do |token|
            assert_includes textarea["class"], token
          end
          refute_includes textarea["class"], "placeholder:text-muted-foreground"
        end

        def test_caller_classes_merge
          textarea = render_textarea(name: "bio", class: "min-h-32 resize-none").css("textarea").first

          assert_includes textarea["class"], "min-h-32"
          assert_includes textarea["class"], "resize-none"
          refute_includes textarea["class"], "min-h-16"
        end
      end
    end
  end
end
