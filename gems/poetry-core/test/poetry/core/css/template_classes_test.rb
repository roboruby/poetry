# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module CSS
      class TemplateClassesTest < Minitest::Test
        def test_extracts_static_classes_only
          result = TemplateClasses.extract(<<~ERB)
            <div class="p-4 rounded">
              <span class="<%= css %> static-too">hi</span>
              <% if condition %><p class="branch-static">x</p><% end %>
              <a data-thing="not-a-class">y</a>
            </div>
          ERB

          assert_empty result.errors
          assert_equal %w[p-4 rounded static-too branch-static].sort, result.classes.sort
          refute_includes result.classes, "not-a-class"
        end

        def test_fully_dynamic_class_attributes_contribute_nothing
          result = TemplateClasses.extract(%(<div class="<%= everything_dynamic %>">x</div>))

          assert_empty result.classes
        end

        def test_parse_errors_are_surfaced_not_swallowed
          result = TemplateClasses.extract("<div <span></div>")

          refute_empty result.errors
        end

        # The herb parse gate (M2): every component template in the gem must
        # parse clean, and its static classes feed the safelist.
        def test_gem_templates_parse_clean
          result = TemplateClasses.scan(root: Poetry::Core.root)

          assert_empty result.errors.map(&:to_s)
        end

        def test_safelist_combines_dictionaries_and_template_classes
          style = Class.new(Poetry::Core::Style) do
            base "inline-flex"
            variant :color, red: "text-red-600"
          end
          safelist = Safelist.new(style_classes: [style], template_classes: %w[p-4 inline-flex])

          assert_equal %w[inline-flex p-4 text-red-600], safelist.classes
          assert safelist.text.start_with?("# poetry Tailwind safelist")
          assert_includes safelist.text, "\ntext-red-600\n"
        end
      end
    end
  end
end
