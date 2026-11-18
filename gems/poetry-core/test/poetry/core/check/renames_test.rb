# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Check
      class RenamesTest < Minitest::Test
        def setup
          @root = Pathname(Dir.mktmpdir("renames"))
        end

        def teardown
          FileUtils.remove_entry(@root)
        end

        def write(name, text)
          @root.join(name).write(text)
          name
        end

        def finding(rule, file, line, subject, suggestion)
          Finding.new(rule: rule, severity: :warning, message: "", file: file, line: line, subject: subject,
                      suggestion: suggestion)
        end

        def apply(*findings, **)
          Renames.new(findings, root: @root).apply(**)
        end

        def test_a_retired_option_is_rewritten_where_the_finding_points
          file = write("show.html.erb", <<~ERB)
            <%= poetry_pill(kind: :soft) { "New" } %>
            <%= poetry_pill(label: "mankind: a note",
                            kind: :soft) %>
          ERB
          changes = apply(finding("deprecated-option", file, 1, "kind", "variant"),
                          finding("deprecated-option", file, 3, "kind", "variant"))

          assert_equal [true, true], changes.map(&:applied)
          assert_equal <<~ERB, @root.join(file).read
            <%= poetry_pill(variant: :soft) { "New" } %>
            <%= poetry_pill(label: "mankind: a note",
                            variant: :soft) %>
          ERB
        end

        def test_a_renamed_icon_keeps_the_form_it_was_written_in
          file = write("icons.html.erb", <<~ERB)
            <%= poetry_icon(name: :"trash-2") %>
            <%= poetry_icon(name: "alert-circle") %>
            <%= poetry_icon(name: :'trash-2', class: "size-4") %>
            <%= poetry_icon(name: :smile) %>
          ERB
          changes = apply(finding("renamed-icon", file, 1, "trash-2", "trash"),
                          finding("renamed-icon", file, 2, "alert-circle", "circle-alert"),
                          finding("renamed-icon", file, 3, "trash-2", "trash"),
                          finding("renamed-icon", file, 4, "smile", "face-slightly-smiling"))

          assert_equal [true, true, true, true], changes.map(&:applied), changes.map(&:reason).inspect
          assert_equal <<~ERB, @root.join(file).read
            <%= poetry_icon(name: :trash) %>
            <%= poetry_icon(name: "circle-alert") %>
            <%= poetry_icon(name: :trash, class: "size-4") %>
            <%= poetry_icon(name: :"face-slightly-smiling") %>
          ERB
        end

        def test_an_icon_declared_in_ruby_is_renamed_too
          file = write("icons.rb", %(ACTION_ICONS = { delete: :"trash-2", close: :x }.freeze\n))
          apply(finding("renamed-icon", file, 1, "trash-2", "trash"))

          assert_equal %(ACTION_ICONS = { delete: :trash, close: :x }.freeze\n), @root.join(file).read
        end

        def test_a_name_written_twice_on_the_line_or_not_at_all_is_left_and_said
          text = %(<%= poetry_pill(kind: :soft) %> <%= poetry_pill(kind: :solid) %>\n<%= poetry_pill %>\n)
          file = write("twice.html.erb", text)
          changes = apply(finding("deprecated-option", file, 1, "kind", "variant"),
                          finding("deprecated-option", file, 2, "kind", "variant"))

          assert_equal [false, false], changes.map(&:applied)
          assert_equal ["written 2 times on this line", "not on this line as written"], changes.map(&:reason)
          assert_equal text, @root.join(file).read
        end

        def test_a_keyword_inside_another_name_or_a_constant_path_is_not_the_option
          text = %(<%= poetry_pill(mankind: 1, Kind::kind, data: { kind: 2 }) %>\n)
          file = write("near.html.erb", text)
          change = apply(finding("deprecated-option", file, 1, "kind", "variant")).sole

          assert change.applied
          assert_equal %(<%= poetry_pill(mankind: 1, Kind::kind, data: { variant: 2 }) %>\n), @root.join(file).read
        end

        def test_a_dry_run_reports_the_changes_and_writes_nothing
          text = %(<%= poetry_pill(kind: :soft) %>\n)
          file = write("dry.html.erb", text)
          change = apply(finding("deprecated-option", file, 1, "kind", "variant"), write: false).sole

          assert change.applied
          assert_equal %w[kind variant], [change.from, change.to]
          assert_equal text, @root.join(file).read
        end

        def test_only_findings_that_carry_a_rename_are_acted_on
          file = write("other.html.erb", %(<%= poetry_pill(kind: :soft) %>\n))
          changes = apply(finding("unknown-option", file, 1, "kind", "variant"),
                          finding("deprecated-option", file, 1, "kind", nil),
                          finding("deprecated-option", file, 1, "kind", "variant"),
                          finding("deprecated-option", file, 1, "kind", "variant"))

          assert_equal 1, changes.size, "a note with no replacement is not a rename, and a finding counts once"
        end

        def test_the_notice_reads_the_same_on_every_surface
          assert_equal "DEPRECATED since 0.2.0 - use variant:", Renames.notice("use" => "variant", "since" => "0.2.0")
          assert_equal "DEPRECATED - pass the icon as content", Renames.notice("note" => "pass the icon as content")
          assert_equal "DEPRECATED - use variant: - kind: reads as a type",
                       Renames.notice("use" => "variant", "note" => "kind: reads as a type")
        end
      end
    end
  end
end
