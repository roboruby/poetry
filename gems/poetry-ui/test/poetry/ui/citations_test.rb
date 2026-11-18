# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # Sources in one shape, and a provider's cited spans as numbered marks.
    class CitationsTest < Minitest::Test
      # A citation as a provider's client hands it over.
      Span = Struct.new(:url, :title, :cited_text, :end_index, keyword_init: true)

      def test_sources_take_one_shape_from_hashes_and_objects
        list = [
          { title: "Fulfilment guide", href: "https://example.com/fulfilment" },
          { "title" => "Refund policy", "url" => "https://example.com/refunds", "description" => "Five days." },
          Span.new(url: "https://example.com/sla", title: "SLA", cited_text: "Two days."),
          { title: " ", url: "" }
        ]

        assert_equal [
          { title: "Fulfilment guide", href: "https://example.com/fulfilment", description: nil },
          { title: "Refund policy", href: "https://example.com/refunds", description: "Five days." },
          { title: "SLA", href: "https://example.com/sla", description: "Two days." }
        ], Citations.sources(list)
      end

      def test_a_source_with_no_title_is_named_by_its_address
        assert_equal "https://example.com/a", Citations.sources([{ url: "https://example.com/a" }]).first[:title]
      end

      def test_cited_spans_become_numbered_marks_after_them
        text = "Orders ship in two days. Refunds take five."
        spans = [
          Span.new(url: "https://example.com/sla", title: "SLA", end_index: 24),
          Span.new(url: "https://example.com/refunds", title: "Refund policy", end_index: 43)
        ]
        marked, sources = Citations.mark(text, spans)

        assert_equal "Orders ship in two days.[1] Refunds take five.[2]", marked
        assert_equal ["SLA", "Refund policy"], sources.pluck(:title)
      end

      def test_a_source_cited_twice_keeps_its_number
        text = "First claim. Second claim. Third claim."
        spans = [
          Span.new(url: "https://example.com/a", title: "A", end_index: 12),
          Span.new(url: "https://example.com/b", title: "B", end_index: 26),
          Span.new(url: "https://example.com/a", title: "A", cited_text: "another passage", end_index: 39)
        ]
        marked, sources = Citations.mark(text, spans)

        assert_equal "First claim.[1] Second claim.[2] Third claim.[1]", marked
        assert_equal 2, sources.size
      end

      def test_two_sources_for_one_span_read_in_order
        spans = [
          Span.new(url: "https://example.com/a", title: "A", end_index: 6),
          Span.new(url: "https://example.com/b", title: "B", end_index: 6)
        ]

        assert_equal "Claim.[1][2] More.", Citations.mark("Claim. More.", spans).first
      end

      def test_a_citation_with_no_span_still_brings_its_source
        marked, sources = Citations.mark("Claim.", [Span.new(url: "https://example.com/a", title: "A"),
                                                    Span.new(url: "https://example.com/b", title: "B", end_index: 99)])

        assert_equal "Claim.", marked
        assert_equal %w[A B], sources.pluck(:title)
      end

      def test_no_citations_leave_the_text_alone
        assert_equal ["Claim.", []], Citations.mark("Claim.", nil)
      end
    end
  end
end
