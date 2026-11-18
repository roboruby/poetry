# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Citation
      class ComponentTest < ViewComponent::TestCase
        def test_with_an_address_it_is_a_link_named_for_its_source
          mark = render_inline(Component.new(number: 2, href: "https://example.com/refunds", title: "Refund policy"))
                 .at_css('[data-slot="citation"]')

          assert_equal "a", mark.name
          assert_equal "2", mark.text
          assert_equal "https://example.com/refunds", mark["href"]
          assert_equal "Source 2: Refund policy", mark["aria-label"]
          assert_equal "Refund policy", mark["title"]
          assert_equal "nofollow noopener noreferrer", mark["rel"]
          assert_includes mark["class"].split, "cn-badge"
        end

        def test_without_a_title_it_is_named_by_its_number
          mark = render_inline(Component.new(number: 3, href: "/orders/1041")).at_css('[data-slot="citation"]')

          assert_equal "Source 3", mark["aria-label"]
          refute mark.key?("title")
        end

        def test_without_an_address_it_is_the_number_alone
          mark = render_inline(Component.new(number: 1)).at_css('[data-slot="citation"]')

          assert_equal "span", mark.name
          assert_equal "1", mark.text
          refute mark.key?("href")
          refute mark.key?("aria-label")
        end

        def test_an_address_the_page_may_not_carry_leaves_the_number_alone
          ["javascript:alert(1)", "data:text/html,x", "java\tscript:alert(1)"].each do |address|
            mark = render_inline(Component.new(number: 1, href: address, title: "x")).at_css('[data-slot="citation"]')

            assert_equal "span", mark.name, address.inspect
            refute mark.key?("href"), address.inspect
          end
        end

        def test_a_callers_target_joins_the_link
          mark = render_inline(Component.new(number: 1, href: "https://example.com", target: "_blank"))
                 .at_css('[data-slot="citation"]')

          assert_equal "_blank", mark["target"]
        end

        def test_a_title_is_text_wherever_it_lands
          html = render_inline(Component.new(number: 1, href: "https://example.com", title: %("><script>x</script>)))

          assert_empty html.css("script")
          assert_equal %(Source 1: "><script>x</script>), html.at_css('[data-slot="citation"]')["aria-label"]
        end
      end
    end
  end
end
