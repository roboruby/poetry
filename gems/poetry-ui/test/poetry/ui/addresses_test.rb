# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The addresses text that is not the host's may put on a page.
    class AddressesTest < Minitest::Test
      def test_a_link_keeps_the_schemes_a_reader_expects
        %w[https://example.com/a http://example.com mailto:a@example.com tel:+15550100].each do |address|
          assert_equal address, Addresses.link(address)
        end
      end

      def test_a_link_may_be_the_hosts_own
        %w[/orders/1041 #totals ?page=2 orders/1041 ./a:b].each do |address|
          assert_equal address, Addresses.link(address), address
        end
      end

      def test_a_link_with_any_other_scheme_is_refused
        ["javascript:alert(1)", "JAVASCRIPT:alert(1)", "data:text/html,x", "vbscript:x", "file:///etc/passwd",
         "java\tscript:alert(1)", "java%09script:alert(1)", "//evil.example/x", "", "  ", nil].each do |address|
          assert_nil Addresses.link(address), address.inspect
        end
      end

      def test_an_image_loads_only_from_an_absolute_web_address
        assert_equal "https://example.com/c.png", Addresses.image("https://example.com/c.png")
        refused = ["/logout", "c.png", "data:image/png;base64,AAAA", "mailto:a@example.com", "//example.com/c.png"]

        refused.each do |address|
          assert_nil Addresses.image(address), address
        end
      end

      def test_surrounding_space_is_dropped_and_the_address_is_otherwise_as_written
        assert_equal "https://example.com/a?b=1#c", Addresses.link("  https://example.com/a?b=1#c \n")
      end

      def test_the_site_of_a_web_address
        assert_equal "example.com", Addresses.host("https://www.example.com/fulfilment?x=1")
        assert_equal "docs.example.com", Addresses.host("http://docs.example.com")
        assert_nil Addresses.host("/orders/1041")
        assert_nil Addresses.host("mailto:a@example.com")
        assert_nil Addresses.host("https://exa mple.com")
      end
    end
  end
end
