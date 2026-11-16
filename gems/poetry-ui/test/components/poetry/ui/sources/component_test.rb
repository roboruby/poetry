# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Sources
      class ComponentTest < ViewComponent::TestCase
        def render_sources(**)
          render_inline(Component.new(**)) do |sources|
            sources.with_source("Fulfilment guide", href: "https://www.example.com/fulfilment")
            sources.with_source("Refund policy", href: "https://example.com/refunds",
                                                 description: "Refunds are issued within five working days.")
            sources.with_source("A note from the team")
          end
        end

        def test_the_count_is_the_control_and_the_list_is_closed_at_first
          html = render_sources
          root = html.at_css('[data-slot="sources"]')
          control = root.at_css("button")

          assert_equal "3 sources", control.text.strip
          assert_equal "false", control["aria-expanded"]
          assert root.at_css("##{control["aria-controls"]}").key?("hidden")
        end

        def test_open_shows_the_list_from_the_start
          html = render_sources(open: true)
          control = html.at_css('[data-slot="sources"] button')

          assert_equal "true", control["aria-expanded"]
          refute html.at_css("##{control["aria-controls"]}").key?("hidden")
        end

        def test_each_source_is_numbered_in_the_order_it_was_added
          items = render_sources.css('ol[data-slot="sources-list"] > li[data-slot="sources-item"]')

          numbers = items.map { |item| item.at_css('[data-slot="citation"]').text }
          titles = items.map { |item| item.at_css('[data-slot="sources-title"]').text.strip }

          assert_equal %w[1 2 3], numbers
          assert_equal ["Fulfilment guide", "Refund policy", "A note from the team"], titles
        end

        def test_a_title_links_to_its_source_in_a_new_tab_and_names_the_site
          first = render_sources.css('[data-slot="sources-item"]').first
          link = first.at_css('a[data-slot="sources-title"]')

          assert_equal "https://www.example.com/fulfilment", link["href"]
          assert_equal "_blank", link["target"]
          assert_equal "nofollow noopener noreferrer", link["rel"]
          assert_equal "example.com", first.at_css('[data-slot="sources-site"]').text
        end

        def test_a_passage_shows_under_its_source_and_only_there
          items = render_sources.css('[data-slot="sources-item"]')

          assert_equal "Refunds are issued within five working days.",
                       items[1].at_css('[data-slot="sources-description"]').text
          assert_nil items[0].at_css('[data-slot="sources-description"]')
        end

        def test_a_source_with_no_address_is_its_title_as_text
          last = render_sources.css('[data-slot="sources-item"]').last

          assert_equal "span", last.at_css('[data-slot="sources-title"]').name
          assert_nil last.at_css('[data-slot="sources-site"]')
        end

        def test_an_address_the_page_may_not_carry_is_no_link
          html = render_inline(Component.new) do |sources|
            sources.with_source(%(<img src=x onerror="x()">), href: "javascript:alert(1)", description: "<b>bold</b>")
          end

          assert_empty html.css("a, img, b")
          assert_equal %(<img src=x onerror="x()">), html.at_css('[data-slot="sources-title"]').text
          assert_equal "<b>bold</b>", html.at_css('[data-slot="sources-description"]').text
        end

        def test_one_source_reads_in_the_singular_and_a_label_replaces_the_count
          one = render_inline(Component.new) { |sources| sources.with_source("Only one") }
          named = render_inline(Component.new(label: "Read more")) { |sources| sources.with_source("Only one") }

          assert_equal "1 source", one.at_css("button").text.strip
          assert_equal "Read more", named.at_css("button").text.strip
        end

        def test_without_a_source_it_raises
          assert_raises(ArgumentError) { render_inline(Component.new) }
        end
      end
    end
  end
end
