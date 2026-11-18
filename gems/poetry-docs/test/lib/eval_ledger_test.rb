require "test_helper"

# The eval ledger: the judged runs as the Evals page shows them, with the
# uncertainty a single draw allows.
class EvalLedgerTest < ActiveSupport::TestCase
  Ledger = Poetry::Docs::EvalLedger

  def stored(dir, verdicts, results = nil)
    folder = Pathname(dir).join("2026-01-01")
    folder.mkpath
    tasks = verdicts.each_with_index.to_h { |verdict, index| [ "task_#{index}", { "verdict" => verdict } ] }
    folder.join("benchmark-verdicts.json").write(JSON.generate("model" => "a-model", "tasks" => tasks))
    folder.join("results.json").write(JSON.generate(results)) if results
  end

  test "the interval is Wilson's: inside nought and one, wide at small counts" do
    assert_equal [ 0.264, 0.592 ], Ledger.wilson(13, 31)
    assert_equal [ 0.0, 0.278 ], Ledger.wilson(0, 10)
    assert_equal [ 0.722, 1.0 ], Ledger.wilson(10, 10)
    assert_equal [ 0.469, 0.531 ], Ledger.wilson(500, 1000)
    assert_nil Ledger.wilson(0, 0)
  end

  test "a run is counted from its verdicts, and its share is of the decided briefs" do
    Dir.mktmpdir do |dir|
      stored(dir, %w[poetry poetry raw_tailwind inconclusive])
      run = Ledger.build(dir).fetch("runs").sole

      assert_equal({ "id" => "2026-01-01", "briefs" => 4, "model" => "a-model", "poetry" => 2, "raw" => 1,
                     "inconclusive" => 1, "share" => 0.667, "interval" => Ledger.wilson(2, 3) }, run)
      refute Ledger.build(dir).key?("degradation")
    end
  end

  test "checks count only what both sides of a brief were scored on" do
    results = { "meta" => { "generation" => { "receipted_cost_usd" => 12.5 } },
                "summary" => { "axes" => { "brief_fit" => { "poetry" => 1, "raw_tailwind" => 0, "tied" => 0 } } },
                "tasks" => { "task_0" => { "gates" => {
                  "poetry" => { "named" => true, "wired" => true, "poetry_only" => true },
                  "raw_tailwind" => { "named" => true, "wired" => false }
                } } } }
    Dir.mktmpdir do |dir|
      stored(dir, %w[poetry], results)
      run = Ledger.build(dir).fetch("runs").sole

      assert_equal({ "passed" => 2, "of" => 2, "rate" => 1.0 }, run.dig("checks", "poetry"))
      assert_equal({ "passed" => 1, "of" => 2, "rate" => 0.5 }, run.dig("checks", "raw"))
      assert_equal({ "poetry" => 1, "raw" => 0, "tied" => 0 }, run.dig("axes", "brief_fit"))
      assert_in_delta 12.5, run["cost_usd"]
    end
  end

  test "the committed ledger matches the runs stored in the repository" do
    assert_equal Ledger.build, Ledger.read, "data/eval-ledger.json is stale - run bundle exec rake poetry_docs:eval_ledger"
    assert_operator Ledger.read.fetch("runs").size, :>=, 15
  end
end
