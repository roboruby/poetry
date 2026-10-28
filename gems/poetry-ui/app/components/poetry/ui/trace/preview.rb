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

        # Steps with detail: one open over its tool output, one closed.
        def with_detail
          render_component do |trace|
            trace.with_step("Ran git status --short", icon: :terminal, description: "0.4s", open: true) do
              render Poetry::Ui::CodeBlock::Component.new(code: " M app/models/invoice.rb\n?? db/migrate/\n",
                                                          size: :sm, wrap: true, copy: false, label: "Output")
            end
            trace.with_step("Thought for 12 seconds", icon: :brain) do
              tag.p("The overdue scope needs a due date, so the migration comes first.")
            end
          end
        end
      end
    end
  end
end
