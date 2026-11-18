# frozen_string_literal: true

module Poetry
  module Ui
    module Trace
      # The Trace preview matrix: the statuses, and steps with detail.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |trace|
            trace.with_step("Searched the docs for \"turbo frames\"", icon: :search, description: "3 results")
            trace.with_step("Read app/models/invoice.rb", icon: :"file-text")
            trace.with_step("Running the test suite", icon: :"flask-conical", status: :running)
            trace.with_step("Failed to reach the billing API", icon: :globe, status: :error)
            trace.with_step("Deploy to staging", icon: :rocket, status: :pending)
          end
        end

        # Steps with detail: one open over its tool output, one closed. A
        # per-example template (a nested component inside a block needs a
        # view context - see Item's group note).
        def with_detail
          render_with_template(template: "poetry/ui/trace/with_detail_preview")
        end
      end
    end
  end
end
