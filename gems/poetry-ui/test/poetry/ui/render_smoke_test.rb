# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # A render smoke, not a benchmark: a catastrophic regression (a
    # per-render eager load, a validation pass per attribute) fails here;
    # the real measurement, with its ratios and its per-method breakdown,
    # lives in the poetry-benchmark repository. The bound is absolute and
    # generous (200 buttons in one view context measured 18 ms on
    # 2026-09-11), so a slow CI box passes and a 20x step change does not.
    class RenderSmokeTest < ActiveSupport::TestCase
      BOUND_MS = 500

      test "two hundred buttons in one view context render inside the bound" do
        template = (1..200).map { |i| %(<%= poetry_button(variant: :ghost, size: :sm) { "Button #{i}" } %>) }.join("\n")
        ApplicationController.render(inline: template, layout: false) # warm
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ApplicationController.render(inline: template, layout: false)
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000

        assert_operator elapsed, :<, BOUND_MS,
                        "200 buttons took #{elapsed.round}ms - a step change; run poetry-benchmark's rake bench:render for the breakdown"
      end
    end
  end
end
