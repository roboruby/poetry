# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Icons
      class FinderTest < Minitest::Test
        NAMES = %i[arrow-left arrow-right circle-alert delete eraser file file-x settings star start trash
                   triangle-alert].freeze
        ALIASES = { "alert-circle" => "circle-alert", "bin" => "trash" }.freeze
        TAGS = {
          "circle-alert" => %w[warning error danger],
          "delete" => %w[backspace remove],
          "eraser" => %w[delete rubber],
          "file-x" => ["lost", "delete", "remove document"],
          "settings" => %w[cog gear preferences],
          "trash" => %w[garbage delete deletion remove],
          "triangle-alert" => %w[warning caution]
        }.freeze

        def setup
          @finder = Finder.new(names: NAMES, aliases: ALIASES, tags: TAGS)
        end

        def names(query, **)
          @finder.find(query, **).map { |match| match[:name] }
        end

        def test_an_icon_is_found_by_what_it_is_used_for
          assert_equal %w[delete eraser trash file-x], names("delete")
          assert_equal %w[circle-alert triangle-alert], names("warning")
          assert_equal ["settings"], names("gear")
        end

        def test_a_name_outranks_a_tag_and_a_whole_name_outranks_a_part_of_one
          assert_equal "delete", names("delete").first
          assert_equal %w[arrow-left arrow-right], names("arrow left")
          assert_equal %w[file file-x], names("file")
        end

        def test_the_icon_that_answers_more_of_the_description_comes_first
          assert_equal "file-x", names("delete a file").first
          assert_equal "circle-alert", names("warning in a circle").first
        end

        def test_a_word_counts_for_as_much_of_a_name_as_the_description_covers
          finder = Finder.new(names: %i[battery-warning engine flag triangle-alert],
                              tags: { "engine" => %w[motor repair warning], "flag" => %w[warning report],
                                      "triangle-alert" => %w[warning danger] })

          found = finder.find("warning").map { |match| match[:name] }

          assert_equal(%w[flag engine triangle-alert battery-warning], found,
                       "the plainer names first, the earlier tag ahead; last the name the word is half of")
          assert_equal "battery-warning", finder.find("battery warning").first[:name]
        end

        def test_a_former_name_still_finds_the_icon
          assert_equal ["trash"], names("bin")
          assert_equal "circle-alert", names("alert-circle").first
        end

        def test_another_form_of_a_word_counts_for_half
          arrows = @finder.find("arrows")

          assert_equal(%w[arrow-left arrow-right], arrows.map { |match| match[:name] })
          assert_equal([1, 1], arrows.map { |match| match[:score] })
          assert_includes names("deleting"), "trash"
          assert_equal %w[star start], names("star"), "a word close to another is a weaker answer, after the exact one"
        end

        def test_filler_words_and_case_are_ignored_and_an_empty_description_answers_nothing
          assert_equal names("delete"), names("Which icon means DELETE?")
          assert_empty names("the icon for")
          assert_empty names("")
          assert_empty names(nil)
          assert_empty names("zeppelin")
        end

        def test_an_answer_says_what_it_matched_and_what_the_icon_is_filed_under
          match = @finder.find("delete a file").first

          assert_equal({ name: "file-x", score: 7, answers: %w[delete file],
                         tags: ["delete", "lost", "remove document"] }, match)
        end

        def test_the_limit_is_kept_between_one_and_fifty
          assert_equal 2, names("delete", limit: 2).size
          assert_equal 1, names("delete", limit: 0).size
          assert_equal 4, names("delete", limit: 500).size
        end

        def test_a_set_without_tags_is_searched_by_name
          bare = Finder.new(names: NAMES)

          assert_equal(%w[trash], bare.find("trash").map { |match| match[:name] })
          assert_empty bare.find("garbage")
        end

        def test_a_word_that_is_no_name_gets_the_icons_filed_under_it_or_the_sets_own_note
          finder = Finder.new(names: NAMES, tags: TAGS, hint: "This set draws no brand marks")

          assert_equal "try :settings", finder.advice(:gear)
          assert_equal "try :\"circle-alert\", :\"triangle-alert\"", finder.advice("warning")
          assert_equal "This set draws no brand marks", finder.advice(:github)
          assert_equal "", Finder.new(names: NAMES).advice(:github)
        end

        def test_an_unknown_icon_says_what_is_filed_under_the_word_when_no_name_is_close
          dir = Pathname.new(Dir.mktmpdir)
          dir.join("trash.svg").write("<path/>")
          dir.join("layout-dashboard.svg").write("<path/>")
          set = FileSet.new(dir: dir, tags: { "layout-dashboard" => %w[dashboard panels] }, hint: "No brands here")

          assert_equal "unknown icon :dashboard (not in this set) - try :\"layout-dashboard\"",
                       assert_raises(IconNotFound) { set.fetch(:dashboard) }.message
          assert_equal "unknown icon :github (not in this set) - No brands here",
                       assert_raises(IconNotFound) { set.fetch(:github) }.message
          assert_equal "unknown icon :trsh (not in this set) - did you mean :trash?",
                       assert_raises(IconNotFound) { set.fetch(:trsh) }.message
        ensure
          FileUtils.rm_rf(dir) if dir
        end

        def test_find_reads_the_registered_set
          dir = Pathname.new(Dir.mktmpdir)
          dir.join("trash.svg").write("<path/>")
          dir.join("star.svg").write("<path/>")
          Icons.register(:finder_test, FileSet.new(dir: dir, tags: { "trash" => %w[delete] }))

          assert_equal(["trash"], Icons.find("delete", :finder_test).map { |match| match[:name] })
          assert_equal(["star"], Icons.find("star", :finder_test, limit: 1).map { |match| match[:name] })
        ensure
          Icons.send(:registry).delete(:finder_test)
          FileUtils.rm_rf(dir) if dir
        end
      end
    end
  end
end
