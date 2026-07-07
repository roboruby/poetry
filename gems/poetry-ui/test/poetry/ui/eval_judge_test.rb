# frozen_string_literal: true

require "test_helper"
require_relative "../../../eval/judge"

module Poetry
  module Ui
    # The paired judge's vote math and honesty invariants (N15 W1) - pure
    # functions, tested without the claude CLI. The subprocess seam
    # (claude_vote) is exercised by the calibration run, not here.
    class EvalJudgeTest < Minitest::Test
      PAIR_AB = %w[poetry raw_tailwind].freeze
      PAIR_BA = %w[raw_tailwind poetry].freeze

      def raw_vote(overall, axis = overall)
        { "overall" => overall,
          "axes" => Poetry::Eval::Judge::AXES.to_h { |name| [name, axis] },
          "rationale" => "because" }
      end

      def vote_for(arm, order)
        { "overall" => arm,
          "axes" => Poetry::Eval::Judge::AXES.to_h { |name| [name, arm] },
          "rationale" => "because", "order" => order }
      end

      def test_normalize_maps_positions_back_to_arm_ids_in_both_orders
        vote = Poetry::Eval::Judge.normalize(raw_vote("first"), PAIR_AB)

        assert_equal "poetry", vote["overall"]
        assert_equal "poetry", vote["axes"]["hierarchy"]

        swapped = Poetry::Eval::Judge.normalize(raw_vote("first"), PAIR_BA)

        assert_equal "raw_tailwind", swapped["overall"]
        assert_equal "raw_tailwind", swapped["axes"]["brief_fit"]
      end

      def test_normalize_rejects_votes_that_are_not_forced_choice
        assert_raises(Poetry::Eval::Judge::Error) do
          Poetry::Eval::Judge.normalize(raw_vote("tie"), PAIR_AB)
        end
        assert_raises(Poetry::Eval::Judge::Error) do
          Poetry::Eval::Judge.normalize(raw_vote("first", "neither"), PAIR_AB)
        end
      end

      def test_decide_unanimous_verdict_survives_the_swap
        votes = Array.new(3) { vote_for("poetry", "ab") } + Array.new(3) { vote_for("poetry", "ba") }
        decision = Poetry::Eval::Judge.decide(votes)

        assert_equal "poetry", decision[:verdict]
        assert_equal 6, decision[:surviving]
        assert_in_delta 1.0, decision[:swap_consistency]
      end

      def test_decide_discards_the_single_order_loner_and_keeps_the_majority
        votes = [vote_for("poetry", "ab"), vote_for("poetry", "ab"), vote_for("poetry", "ba"),
                 vote_for("poetry", "ba"), vote_for("poetry", "ba"), vote_for("raw_tailwind", "ab")]
        decision = Poetry::Eval::Judge.decide(votes)

        assert_equal "poetry", decision[:verdict]
        assert_equal 5, decision[:surviving]
        assert_in_delta 0.833, decision[:swap_consistency]
      end

      def test_decide_flags_a_pure_position_split_as_inconclusive
        # A position-biased judge always picks whatever is shown FIRST:
        # normalized, that is one arm across all ab votes and the OTHER arm
        # across all ba votes - neither verdict survives the swap.
        votes = Array.new(3) { vote_for("poetry", "ab") } + Array.new(3) { vote_for("raw_tailwind", "ba") }
        decision = Poetry::Eval::Judge.decide(votes)

        assert_equal "inconclusive", decision[:verdict]
        assert_equal 0, decision[:surviving]
        assert_in_delta 0.0, decision[:swap_consistency]
      end

      def test_decide_mixed_split_where_both_verdicts_survive_is_inconclusive
        votes = [vote_for("poetry", "ab"), vote_for("poetry", "ab"), vote_for("poetry", "ba"),
                 vote_for("raw_tailwind", "ab"), vote_for("raw_tailwind", "ba"), vote_for("raw_tailwind", "ba")]
        decision = Poetry::Eval::Judge.decide(votes)

        assert_equal "inconclusive", decision[:verdict]
        assert_equal 6, decision[:surviving]
      end

      def test_decide_majority_wins_when_both_groups_survive_unevenly
        votes = [vote_for("poetry", "ab"), vote_for("poetry", "ab"), vote_for("poetry", "ba"),
                 vote_for("poetry", "ba"), vote_for("raw_tailwind", "ab"), vote_for("raw_tailwind", "ba")]
        decision = Poetry::Eval::Judge.decide(votes)

        assert_equal "poetry", decision[:verdict]
        assert_equal 6, decision[:surviving]
      end

      def test_axis_tallies_count_per_arm_over_all_votes
        votes = [vote_for("poetry", "ab"), vote_for("poetry", "ba"), vote_for("raw_tailwind", "ab")]
        tallies = Poetry::Eval::Judge.axis_tallies(votes, PAIR_AB)

        assert_equal({ "poetry" => 2, "raw_tailwind" => 1 }, tallies["hierarchy"])
        assert_equal Poetry::Eval::Judge::AXES.sort, tallies.keys.sort
      end

      def test_build_prompt_is_blind_and_carries_brief_paths_and_ledgers
        prompt = Poetry::Eval::Judge.build_prompt(
          brief: "A settings dialog opened by a button",
          first_path: "/tmp/eval_judge/dialog/ab/first.png",
          second_path: "/tmp/eval_judge/dialog/ab/second.png",
          first_ledger: "renders pass | labelled_overlay pass",
          second_ledger: "renders pass | labelled_overlay FAIL"
        )

        assert_includes prompt, "A settings dialog opened by a button"
        assert_includes prompt, "first.png"
        assert_includes prompt, "labelled_overlay FAIL"
        # The honesty invariant: nothing in the prompt names an arm.
        Poetry::Eval::Judge.assert_blind!(prompt, PAIR_AB + ["eval/captures"])
      end

      def test_assert_blind_raises_on_an_identity_leak
        error = assert_raises(Poetry::Eval::Judge::Error) do
          Poetry::Eval::Judge.assert_blind!("compare the poetry arm against the other", ["poetry"])
        end
        assert_match(/leaks arm identity/, error.message)
      end

      def test_extract_json_tolerates_code_fences_and_rejects_prose
        fenced = "```json\n{\"overall\":\"first\"}\n```"

        assert_equal({ "overall" => "first" }, Poetry::Eval::Judge.extract_json(fenced))
        assert_raises(Poetry::Eval::Judge::Error) { Poetry::Eval::Judge.extract_json("no json here") }
      end

      def test_extract_json_repairs_the_dangling_quote_the_judge_emitted_live
        # Verbatim tail shape from the crashed calibration run: a trailing
        # `,"` before the closing brace.
        live = '{"overall":"second","axes":{"hierarchy":"first"},"rationale":"near-identical.","}'

        assert_equal "second", Poetry::Eval::Judge.extract_json(live)["overall"]
      end

      def test_tally_discards_malformed_votes_without_killing_the_verdict
        votes = Array.new(3) { vote_for("poetry", "ab") } + Array.new(2) { vote_for("poetry", "ba") } +
                [{ "overall" => "malformed", "axes" => {}, "order" => "ba", "rationale" => "discarded: junk" }]
        tally = Poetry::Eval::Judge.tally(votes)

        assert_equal "poetry", tally["verdict"]
        assert_equal 5, tally["surviving_votes"]
        assert_equal 1, tally["malformed_votes"]
        assert_in_delta 0.833, tally["swap_consistency"]
      end

      def test_render_ledger_spells_out_pass_and_fail
        rendered = Poetry::Eval::Judge.render_ledger({ "renders" => true, "caption_present" => false })

        assert_equal "renders pass | caption_present FAIL", rendered
      end
    end
  end
end
