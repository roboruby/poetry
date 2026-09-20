# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require_relative "../../../eval/manifest"

module Poetry
  module Eval
    class ManifestTest < Minitest::Test
      def test_a_new_manifest_starts_empty_and_writes_whole_on_record
        Dir.mktmpdir do |dir|
          path = Pathname(dir).join("run", "generation-manifest.json")
          manifest = Manifest.new(path)
          manifest.config = { "model" => "m" }

          assert_in_delta 0.0, manifest.prior_receipted
          manifest.record("card", "poetry", { "cost_usd" => 0.5 }, { "receipted_cost_usd" => 0.5 })

          reread = Manifest.new(path)

          assert_equal({ "cost_usd" => 0.5 }, reread.entry("card", "poetry"))
          assert_equal({ "model" => "m" }, reread.data["config"])
          assert_in_delta 0.5, reread.prior_receipted
          assert_equal 1, reread.entries.size
        end
      end

      def test_pending_skips_a_recorded_unit_with_its_artifact_and_retries_errors_and_missing_artifacts
        Dir.mktmpdir do |dir|
          manifest = Manifest.new(Pathname(dir).join("m.json"))
          manifest.record("card", "poetry", { "cost_usd" => 1 }, {})
          manifest.record("card", "raw", { "error" => "timed out" }, {})
          manifest.record("form", "poetry", { "cost_usd" => 1 }, {})
          units = [%w[card poetry], %w[card raw], %w[form poetry], %w[form raw]]
          present = { %w[card poetry] => true, %w[form poetry] => false }

          pending = manifest.pending(units) { |task, arm| present.fetch([task, arm], false) }

          assert_equal [%w[card raw], %w[form poetry], %w[form raw]], pending
          assert_equal units, manifest.pending(units, force: true) { true }
        end
      end
    end
  end
end
