# frozen_string_literal: true

require "test_helper"
require_relative "../../../eval/pagescale"

module Poetry
  module Eval
    # The page-scale companion gate's integrity contract: the spec
    # is shaped like the standing TASKS, the briefs stay free of block
    # vocabulary (the gate must measure page-scale value, not block-lookup
    # luck), and the gates are UNIFORM - no per-task gate tailoring.
    class PagescaleTest < Minitest::Test
      # Block names, router jargon, and poetry vocabulary that would make
      # a brief lead the witness.
      FORBIDDEN = /\b(?:blocks?|app.shell|data.index|section.card|top.nav|destructive.panel|
                       page.header|compose|poetry)\b/xi

      def test_twelve_briefs_in_the_standing_schema
        assert_equal 12, Pagescale::TASKS.size
        Pagescale::TASKS.each do |name, spec|
          assert_match(/\A[a-z0-9_]+\z/, name, "task names must be route-safe")
          assert_operator spec["description"].length, :>=, 80,
                          "#{name}: a page-scale brief describes a screen, not a widget"
          assert_equal Pagescale::GATES, spec["gates"], "#{name}: gates are uniform by design"
        end
      end

      def test_briefs_carry_no_block_vocabulary
        Pagescale::TASKS.each do |name, spec|
          refute_match FORBIDDEN, spec["description"],
                       "#{name}: briefs must not lead the witness toward blocks"
        end
      end

      def test_no_task_name_collides_with_the_standing_benchmark
        assert_empty Pagescale::TASKS.keys & Runner::TASKS.keys
      end

      def test_the_uniform_gates_score_real_markup
        page = Nokogiri::HTML5.fragment(
          "<main><header><h1>Billing</h1></header><section><table><tr><td>x</td></tr></table>" \
          "</section><form><div></div></form><ul><li>a</li></ul></main>"
        )
        empty = Nokogiri::HTML5.fragment("<button>x</button>")

        assert Pagescale::RENDERS.check.call(page, "")
        assert Pagescale::HAS_HEADING.check.call(page, "")
        refute Pagescale::RENDERS.check.call(empty, ""),
               "a lone component must not pass the page-scale renders gate"
        refute Pagescale::HAS_HEADING.check.call(empty, "")
      end

      def test_runner_accepts_a_task_spec_override
        Dir.mktmpdir("pagescale-arms") do |dir|
          Pathname(dir).join("login").mkpath
          Pathname(dir).join("login/poetry.html.erb").write("<main><h1>Sign in</h1></main>")
          runner = Runner.new(arms_root: dir, tasks: Pagescale::TASKS.slice("login"))
          card = runner.scorecard(fold_judged: false)

          assert_equal ["login"], card["tasks"].keys
          assert card.dig("tasks", "login", "arms", "poetry"),
                 "the override's tasks drive scoring end to end"
        end
      end
    end
  end
end
