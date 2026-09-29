# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Check
      class TagHelpersTest < Minitest::Test
        def test_a_splat_on_a_tag_helper_is_flagged_with_the_element_tag_to_write
          finding = lint(%(<%= tag.div(**root_attributes) do %>x<% end %>)).first

          assert_equal "element-tag", finding.rule
          assert_equal :warning, finding.severity
          assert_equal 1, finding.line
          assert_match(/tag\.div takes attributes .* drops them/, finding.message)
          assert_match(/element_tag\(:div, \.\.\.\)/, finding.message)
        end

        def test_a_splat_on_content_tag_is_flagged
          finding = lint(%(<%= content_tag(:button, **root_attributes) do %>x<% end %>)).first

          assert_match(/content_tag takes attributes/, finding.message)
          assert_match(/element_tag\(:button, \.\.\.\)/, finding.message)
        end

        def test_attributes_held_in_a_variable_are_flagged_when_a_block_makes_them_options
          assert_equal 1, lint(%(<%= content_tag(:div, attrs) do %>x<% end %>)).size
          assert_equal 1, lint(%(<%= tag.div(attrs) do %>x<% end %>)).size
          assert_empty lint(%(<%= content_tag(:span, title, class: "a") %>))
        end

        def test_a_tag_name_held_in_a_variable_is_flagged
          finding = lint(%(<%= content_tag(root_tag, class: "a") do %>x<% end %>)).first

          assert_match(/takes its tag name from a variable, which stops the template compiling/, finding.message)
          assert_match(/element_tag\(root_tag, \.\.\.\)/, finding.message)
        end

        def test_tag_attributes_is_flagged_for_a_splat_and_kept_for_a_hash
          finding = lint(%(<div <%= tag.attributes(**stimulus_attributes_for(:grid)) %>></div>)).first

          assert_match(/pass it as an argument: tag\.attributes\(stimulus_attributes_for\(:grid\)\)/, finding.message)
          assert_empty lint(%(<div <%= tag.attributes(stimulus_attributes_for(:grid)) %>></div>))
        end

        def test_literal_keywords_are_what_a_slot_compile_reads_right
          assert_empty lint(%(<%= tag.input(type: "hidden", name: name, value: "0") %>))
          assert_empty lint(%(<%= content_tag(:span, "Title", class: "a") %>))
        end

        def test_element_tag_and_other_helpers_are_left_alone
          assert_empty lint(%(<%= element_tag(root_tag, **root_attributes) do %>x<% end %>))
          assert_empty lint(%(<%= poetry_card(**attrs) do %>x<% end %>))
          assert_empty lint(%(<%= form.tag.div(**attrs) %>))
        end

        def test_a_comment_or_an_escaped_tag_is_not_code
          assert_empty lint(%(<%# tag.div(**attrs) is the old form %>))
          assert_empty lint(%(<%%= tag.div(**attrs) %>))
        end

        def test_the_line_is_the_line_of_the_call
          source = <<~ERB
            <div>
              <%= render(Thing.new) do %>
                <%= tag.span(**label_attributes) do %>x<% end %>
              <% end %>
            </div>
          ERB

          assert_equal [3], lint(source).map(&:line)
        end

        # The rule poetry's own templates are held to.
        def test_strict_flags_every_call_to_an_action_view_tag_helper
          strict = TagHelpers.new(strict: true)

          assert_equal 1, strict.lint(%(<%= tag.input(type: "hidden", name: name) %>)).size
          assert_equal 1, strict.lint(%(<%= content_tag(:span, "Title", class: "a") %>)).size
          assert_empty strict.lint(%(<div <%= tag.attributes(attrs) %>></div>))
          assert_empty strict.lint(%(<%= element_tag(:span, "Title", class: "a") %>))
        end

        private

        def lint(source)
          TagHelpers.new.lint(source)
        end
      end
    end
  end
end
