# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module CSS
      # The .cn-* override contract: undeclared host overrides are
      # drift, declared ones are intent, and the declaration rules make the
      # accidental blanket impossible.
      class OverrideScanTest < Minitest::Test
        CSS_WITH_OVERRIDES = <<~CSS
          /* .cn-comment-only { ignored } */
          .style-vega .cn-button { border-radius: 0; }
          .cn-card, .cn-card-header { padding: 0; }
        CSS

        def test_undeclared_overrides_are_reported_with_a_paste_ready_snippet
          scan = OverrideScan.new(sources: { "app/assets/site.css" => CSS_WITH_OVERRIDES },
                                  declarations: [])

          refute_predicate scan, :ok?
          path, classes = scan.undeclared.first

          assert_equal "app/assets/site.css", path
          assert_equal %w[cn-button cn-card cn-card-header], classes
          refute_includes classes, "cn-comment-only", "comments never count"
          assert_match(/reason: "TODO/, scan.snippet_for(path, classes))
        end

        def test_declared_overrides_pass_by_class_and_by_file_glob
          declarations = [
            { "cn" => "cn-button", "reason" => "vega switcher radius", "created" => "2026-07-18" },
            { "cn" => "*", "files" => ["app/assets/site.css"], "reason" => "demo page", "created" => "2026-07-18" }
          ]
          scan = OverrideScan.new(sources: { "app/assets/site.css" => CSS_WITH_OVERRIDES },
                                  declarations: declarations)

          assert_predicate scan, :ok?
          assert_empty scan.undeclared
          assert_empty scan.stale
        end

        # Ownership, not authorship: a host's own cn-* classes (a kit's
        # dictionary, a page helper) are never overrides; a rule against a
        # theme-owned name is, whoever wrote it.
        def test_only_theme_owned_names_are_overrides_when_the_owned_set_is_given
          css = ".cn-button { color: red; } .cn-acme-pill { color: blue; } .cn-page-hero { margin: 0; }"
          scan = OverrideScan.new(sources: { "app/assets/kit.css" => css }, declarations: [],
                                  owned: %w[cn-button cn-card])

          assert_equal [["app/assets/kit.css", ["cn-button"]]], scan.undeclared
          only_host = OverrideScan.new(sources: { "app/assets/kit.css" => ".cn-acme-pill { color: blue; }" },
                                       declarations: [], owned: %w[cn-button])

          assert_predicate only_host, :ok?
          assert_empty only_host.undeclared
          everything = OverrideScan.new(sources: { "app/assets/kit.css" => css }, declarations: [])

          assert_equal %w[cn-acme-pill cn-button cn-page-hero], everything.undeclared.first.last, "nil owned: all cn-*"
        end

        def test_wildcard_without_files_is_invalid
          scan = OverrideScan.new(sources: {},
                                  declarations: [{ "cn" => "*", "reason" => "everything" }])

          refute_predicate scan, :ok?
          assert_match(/must be file-scoped/, scan.invalid.first)
        end

        def test_reason_is_required
          scan = OverrideScan.new(sources: {}, declarations: [{ "cn" => "cn-button" }])

          refute_predicate scan, :ok?
          assert_match(/`reason` is required/, scan.invalid.first)
        end

        def test_stale_declarations_are_surfaced_but_do_not_fail
          scan = OverrideScan.new(sources: { "a.css" => ".plain { color: red }" },
                                  declarations: [{ "cn" => "cn-ghost", "reason" => "old", "created" => "2026-01-01" }])

          assert_predicate scan, :ok?
          assert_equal 1, scan.stale.size
        end

        def test_file_scoping_limits_the_declaration
          declarations = [{ "cn" => "*", "files" => ["app/assets/other.css"],
                            "reason" => "scoped elsewhere", "created" => "2026-07-18" }]
          scan = OverrideScan.new(sources: { "app/assets/site.css" => ".cn-button { color: red }" },
                                  declarations: declarations)

          refute_predicate scan, :ok?
          assert_equal [["app/assets/site.css", %w[cn-button]]], scan.undeclared
        end
      end
    end
  end
end
