# frozen_string_literal: true

require "test_helper"

module Poetry
  module Agent
    class GapReportTest < Minitest::Test
      def test_a_report_is_a_title_a_body_and_a_link_that_holds_both
        report = GapReport.new(summary: "Badge has no warning variant", kind: "variant", component: "badge",
                               wanted: "An amber badge.", client: "claude-code")
        query = URI.decode_www_form(URI(report.url).query).to_h

        assert_equal "Gap: Badge has no warning variant", report.title
        assert_equal report.title, query["title"]
        assert_equal report.body, query["body"]
        assert_equal <<~BODY.chomp, report.body
          **Kind:** variant
          **Component:** badge
          **What the task needed:** An amber badge.

          Reported through poetry-agent #{VERSION}, claude-code.
        BODY
      end

      def test_long_and_ragged_text_is_cut_and_flattened_so_the_link_stays_a_link
        report = GapReport.new(summary: "A\n  summary   over\tlines #{"x" * 300}", wanted: "w" * 2000)

        assert_operator report.title.length, :<=, 5 + GapReport::SUMMARY_LIMIT
        refute_includes report.title, "\n"
        assert report.title.end_with?("…")
        assert_operator report.url.length, :<, 4000
        assert_match(%r{\Ahttps://github\.com/roboruby/poetry/issues/new\?[\w%+.&=*-]+\z}, report.url)
      end

      def test_an_unknown_kind_is_other_and_empty_fields_are_left_out
        report = GapReport.new(summary: "No timeline", kind: "<script>", component: " ")

        assert_includes report.body, "**Kind:** other"
        refute_includes report.body, "Component"
        refute_includes report.body, "script"
      end

      def test_the_printed_report_says_nothing_was_sent
        text = GapReport.new(summary: "No timeline").to_s

        assert_equal "Nothing was sent. To report this, open the link and press Submit:", text.lines.first.chomp
        assert_includes text, "Title: Gap: No timeline"
      end
    end
  end
end
