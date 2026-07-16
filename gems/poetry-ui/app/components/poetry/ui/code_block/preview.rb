# frozen_string_literal: true

module Poetry
  module Ui
    module CodeBlock
      class Preview < Poetry::Core::Preview::Base
        RUBY_SAMPLE = <<~RUBY
          class Invoice < ApplicationRecord
            belongs_to :customer

            # Only settled invoices count toward revenue.
            scope :settled, -> { where(status: "settled") }

            def total
              line_items.sum(&:amount)
            end
          end
        RUBY

        def default
          render_component(code: RUBY_SAMPLE, language: "ruby", label: "Invoice model")
        end

        # CSS-counter line numbers (never in copied text) + .hll tints on
        # the named lines.
        def numbered_and_highlighted
          render_component(code: RUBY_SAMPLE, language: "ruby", label: "Invoice model",
                           line_numbers: true, highlight_lines: [5, 7, 8, 9])
        end

        def without_copy
          render_component(code: %(export POETRY_THEME=vega\nbin/rake test:visual), language: "shell",
                           label: "Gate commands", copy: false)
        end
      end
    end
  end
end
