# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require_relative "../../../eval/runner"
require_relative "../../../eval/judge"
require_relative "../../../eval/benchmark"

module Poetry
  module Ui
    # The generated-arm benchmark's pure surfaces (N15 W2): the hermeticity
    # invariant, the one-prompt rule, the aggregate math behind the
    # pre-registered predictions, and the runner's swappable-corpus seam.
    # The claude CLI seam (claude_generate) is exercised by the run itself,
    # receipts-first, not here.
    class EvalBenchmarkTest < Minitest::Test
      ARMS = %w[poetry raw_tailwind].freeze

      # --- hermeticity ----------------------------------------------------

      def test_assert_hermetic_passes_a_clean_tree_and_prompt
        Dir.mktmpdir("bench-hermetic") do |dir|
          File.write(File.join(dir, "AGENTS.md"), "Rails + Tailwind. Hand-authored UI.")

          assert_nil Poetry::Eval::Benchmark.assert_hermetic!(Pathname(dir), prompt: "build a card")
        end
      end

      def test_assert_hermetic_raises_on_file_body_leak
        Dir.mktmpdir("bench-hermetic") do |dir|
          File.write(File.join(dir, "AGENTS.md"), "Uses the Poetry component library.")

          error = assert_raises(Poetry::Eval::Benchmark::HermeticityError) do
            Poetry::Eval::Benchmark.assert_hermetic!(Pathname(dir))
          end

          assert_match(/file body AGENTS.md/, error.message)
        end
      end

      def test_assert_hermetic_raises_on_file_name_and_prompt_leaks
        Dir.mktmpdir("bench-hermetic") do |dir|
          File.write(File.join(dir, "poetry-notes.txt"), "clean body")

          assert_raises(Poetry::Eval::Benchmark::HermeticityError) do
            Poetry::Eval::Benchmark.assert_hermetic!(Pathname(dir))
          end
        end
        Dir.mktmpdir("bench-hermetic") do |dir|
          assert_raises(Poetry::Eval::Benchmark::HermeticityError) do
            Poetry::Eval::Benchmark.assert_hermetic!(Pathname(dir), prompt: "use the poetry_card helper")
          end
        end
      end

      # --- the guided treatment (the toolbelt asymmetry) ------------

      def with_env(vars)
        prior = vars.to_h { |key, _| [key, ENV.fetch(key, nil)] }
        vars.each { |key, value| ENV[key] = value }
        yield
      ensure
        prior.each { |key, value| ENV[key] = value }
      end

      def test_build_page_belt_and_guided_routing_are_orthogonal
        # Neither flag: the standing belt, no build_page (the standing spec).
        with_env("POETRY_BENCH_BUILD_PAGE" => nil, "POETRY_BENCH_GUIDED" => nil) do
          refute_includes Poetry::Eval::Benchmark.toolbelt("poetry"), "build_page"
        end
        # Availability WITHOUT routing = the guided-eval control: build_page
        # is allowed in the belt (no denied attempts) but not routed.
        with_env("POETRY_BENCH_BUILD_PAGE" => "1", "POETRY_BENCH_GUIDED" => nil) do
          assert_predicate Poetry::Eval::Benchmark, :build_page_available?
          refute_predicate Poetry::Eval::Benchmark, :guided?
          assert_includes Poetry::Eval::Benchmark.toolbelt("poetry"), "mcp__poetry__build_page"
          assert_includes Poetry::Eval::Benchmark.toolbelt("poetry"), "mcp__poetry__compose", "ADDS, never replaces"
        end
        # Routing implies availability (the treatment).
        with_env("POETRY_BENCH_BUILD_PAGE" => nil, "POETRY_BENCH_GUIDED" => "1") do
          assert_includes Poetry::Eval::Benchmark.toolbelt("poetry"), "mcp__poetry__build_page"
        end
      end

      def test_the_raw_belt_is_never_touched_and_the_manifest_records_the_treatment
        with_env("POETRY_BENCH_BUILD_PAGE" => "1", "POETRY_BENCH_GUIDED" => "1") do
          resolved = Poetry::Eval::Benchmark.resolved_toolbelts

          assert_includes resolved["poetry"], "build_page"
          assert_equal Poetry::Eval::Benchmark::TOOLBELTS.fetch("raw_tailwind"), resolved["raw_tailwind"]
        end
      end

      def test_parse_generation_stream_extracts_the_tool_trace_and_envelope
        stream = [
          { "type" => "system", "subtype" => "init" },
          { "type" => "assistant", "message" => { "content" => [
            { "type" => "text", "text" => "planning the page" },
            { "type" => "tool_use", "name" => "mcp__poetry__build_page" }
          ] } },
          { "type" => "assistant", "message" => { "content" => [
            { "type" => "tool_use", "name" => "mcp__poetry__compose" }
          ] } },
          { "type" => "result", "subtype" => "success", "total_cost_usd" => 0.5,
            "num_turns" => 7, "is_error" => false }
        ].map { |obj| JSON.generate(obj) }.join("\n")

        envelope, tools = Poetry::Eval::Benchmark.parse_generation_stream(stream)

        assert_equal 7, envelope["num_turns"]
        assert_equal %w[mcp__poetry__build_page mcp__poetry__compose], tools
        # A stream with no result object (a crash) yields a nil envelope, and
        # a garbage line is skipped, never raised.
        nil_env, = Poetry::Eval::Benchmark.parse_generation_stream("not json\n")

        assert_nil nil_env
      end

      # --- the one-prompt rule ---------------------------------------------

      def test_generation_prompt_has_no_arm_parameter_and_never_names_the_house
        prompt = Poetry::Eval::Benchmark.generation_prompt(task: "card", brief: "A plan card")

        refute_match(/poetry/i, prompt)
        assert_includes prompt, "app/views/eval/card.html.erb"
        assert_includes prompt, "The brief: A plan card"
        assert_includes prompt, "reply with exactly: DONE"
        # Truthful toolbelt disclosure (denied Bash flailing burned turns
        # in the wild); "any checking tools AGENTS.md documents" stays
        # arm-neutral - only host A's AGENTS.md documents any (bin/check +
        # the MCP server since).
        assert_includes prompt, "Your tools are Read, Glob, Grep, and Write, " \
                                "plus any checking tools AGENTS.md documents."
        # No arm keyword exists, so no arm conditional can creep in.
        assert_equal %i[task brief],
                     Poetry::Eval::Benchmark.method(:generation_prompt).parameters.map(&:last)
      end

      # --- gate buckets ----------------------------------------------------

      def test_gate_buckets_categorize_the_prediction_surface
        assert_equal "slop", Poetry::Eval::Benchmark.gate_bucket(:design_slop)
        assert_equal "slop", Poetry::Eval::Benchmark.gate_bucket(:no_raw_colors)
        assert_equal "a11y", Poetry::Eval::Benchmark.gate_bucket(:labelled_overlay)
        assert_equal "a11y", Poetry::Eval::Benchmark.gate_bucket(:focus_visible_treatment)
        assert_equal "content", Poetry::Eval::Benchmark.gate_bucket(:content_complete)
        assert_equal "structure", Poetry::Eval::Benchmark.gate_bucket(:real_table)
      end

      # --- aggregate math ----------------------------------------------------

      def synthetic_inputs
        gates = lambda do |poetry_passes, raw_passes|
          { "poetry" => { "cross_arm" => { "labelled_overlay" => poetry_passes, "design_slop" => poetry_passes,
                                           "real_table" => true } },
            "raw_tailwind" => { "cross_arm" => { "labelled_overlay" => raw_passes, "design_slop" => raw_passes,
                                                 "real_table" => true } } }
        end
        scorecard = { "tasks" => {
          "alpha" => { "arms" => gates.call(true, false) },
          "beta" => { "arms" => gates.call(true, true) },
          "gamma" => { "arms" => gates.call(true, false) },
          "delta" => { "arms" => { "poetry" => { "cross_arm" => { "real_table" => true } } } } # incomplete
        } }
        tally = ->(p, r) { { "poetry" => p, "raw_tailwind" => r } }
        verdicts = { "tasks" => {
          "alpha" => { "brief" => "a", "verdict" => "poetry", "swap_consistency" => 1.0,
                       "axis_tallies" => Poetry::Eval::Judge::AXES.to_h { |axis| [axis, tally.call(6, 0)] } },
          "beta" => { "brief" => "b", "verdict" => "raw_tailwind", "swap_consistency" => 0.833,
                      "axis_tallies" => { "hierarchy" => tally.call(2, 4), "composition" => tally.call(1, 5),
                                          "clarity" => tally.call(3, 3), "brief_fit" => tally.call(4, 2) } },
          "gamma" => { "brief" => "c", "verdict" => "inconclusive", "swap_consistency" => 0.5,
                       "axis_tallies" => Poetry::Eval::Judge::AXES.to_h { |axis| [axis, tally.call(4, 2)] } },
          "delta" => { "brief" => "d", "verdict" => "poetry", "swap_consistency" => 1.0,
                       "axis_tallies" => {} }
        } }
        manifest = { "units" => {
          "alpha" => { "poetry" => { "cost_usd" => 0.5 }, "raw_tailwind" => { "cost_usd" => 0.4 } }
        } }
        [scorecard, verdicts, manifest]
      end

      def test_aggregate_counts_wins_axes_deltas_and_incomplete
        scorecard, verdicts, manifest = synthetic_inputs
        payload = Poetry::Eval::Benchmark.aggregate(
          scorecard: scorecard, verdicts: verdicts, manifest: manifest, meta: { "note" => "test" }
        )

        assert_equal "results-v1", payload["schema"]
        assert_equal %w[delta], payload["incomplete"] # judged but not fully scored
        assert_equal 3, payload["tasks"].size
        assert_equal({ "poetry" => 1, "raw_tailwind" => 1, "inconclusive" => 1 },
                     payload["summary"]["overall"])

        win = payload["summary"]["win_rate"]

        assert_equal [1, 3], win["poetry_headline"].values_at("n", "of")
        assert_equal [1, 2], win["poetry_decided"].values_at("n", "of")

        axes = payload["summary"]["axes"]

        assert_equal 2, axes["hierarchy"]["poetry"]        # alpha + gamma
        assert_equal 1, axes["hierarchy"]["raw_tailwind"]  # beta
        assert_equal 1, axes["clarity"]["tied"]            # beta's 3-3

        # labelled_overlay and design_slop both go poetry 3/3 vs raw 1/3 ->
        # delta 0.667; the alphabetical tiebreak ranks design_slop first.
        top, second = payload["summary"]["gate_deltas_ranked"].first(2)

        assert_equal %w[design_slop labelled_overlay], [top["gate"], second["gate"]]
        assert_in_delta 0.667, top["delta"], 0.001
        assert_equal %w[slop a11y], [top["bucket"], second["bucket"]]
        assert_equal 3, top["runs"]
      end

      def test_aggregate_checks_the_preregistered_predictions
        scorecard, verdicts, manifest = synthetic_inputs
        predictions = Poetry::Eval::Benchmark.aggregate(
          scorecard: scorecard, verdicts: verdicts, manifest: manifest
        )["predictions"]

        refute predictions["p1_overall"]["held"] # 1/3 headline < 70%
        assert_equal %w[a11y slop],
                     predictions["p2_widest_gaps"]["observed_bucket_deltas"].keys.first(2).sort
        assert predictions["p2_widest_gaps"]["held"]
        assert_equal %w[beta], predictions["p3_blocks_signal"]["tasks_where_raw_won_composition"]
        assert predictions["p3_blocks_signal"]["triggered"]
      end

      def test_axis_winners_handles_ties_and_missing_tallies
        winners = Poetry::Eval::Benchmark.axis_winners(
          { "hierarchy" => { "poetry" => 3, "raw_tailwind" => 3 },
            "composition" => { "poetry" => 5, "raw_tailwind" => 1 } }
        )

        assert_equal "tied", winners["hierarchy"]
        assert_equal "poetry", winners["composition"]
        assert_empty Poetry::Eval::Benchmark.axis_winners(nil)
      end

      # --- the runner's swappable corpus ------------------------------------

      def test_runner_scores_an_alternate_arms_root_and_records_render_errors
        Dir.mktmpdir("bench-arms") do |dir|
          FileUtils.mkdir_p(File.join(dir, "card"))
          File.write(File.join(dir, "card/poetry.html.erb"), "<% raise 'boom' %>")
          File.write(File.join(dir, "card/raw_tailwind.html.erb"),
                     %(<div><h3>Team plan</h3><a href="/x">Learn more</a><span>beta</span></div>))

          card = Poetry::Eval::Runner.new(arms_root: dir).scorecard(fold_judged: false)

          refute card.key?("judged")
          arms = card.dig("tasks", "card", "arms")

          assert_match(/boom/, arms["poetry"]["render_error"])
          assert_predicate arms["poetry"]["cross_arm"].values, :none?
          assert arms["raw_tailwind"]["cross_arm"][:real_link] # symbol keys pre-JSON
          assert_empty card.dig("tasks", "dialog", "arms") # absent tasks stay empty, not errors
        end
      end
    end
  end
end
