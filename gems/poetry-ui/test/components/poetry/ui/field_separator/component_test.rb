# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module FieldSeparator
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def test_bare_form_draws_the_rule_and_marks_no_content
          html = render_inline(Component.new).to_html
          root = doc(html).at_css("[data-slot=field-separator]")

          assert_equal "false", root["data-content"]
          assert_includes root["class"], "cn-field-separator"
          rule = root.at_css("[data-slot=separator]")

          # The rule is a decorative Separator drawn across the row.
          assert_equal "true", rule["aria-hidden"]
          assert_includes rule["class"], "absolute"
          assert_nil root.at_css("[data-slot=field-separator-content]")
        end

        def test_caption_form_floats_the_text_on_the_line
          html = render_inline(Component.new.with_content("Or continue with")).to_html
          root = doc(html).at_css("[data-slot=field-separator]")

          assert_equal "true", root["data-content"]
          caption = root.at_css("[data-slot=field-separator-content]")

          assert_equal "Or continue with", caption.text
          # Backed by the page background so the line breaks around it.
          assert_includes caption["class"], "bg-background"
        end
      end
    end
  end
end
