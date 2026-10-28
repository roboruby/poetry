# frozen_string_literal: true

module Poetry
  module Ui
    module CodeBlock
      # The CodeBlock preview: highlighted Ruby, numbered and highlighted
      # lines, the copy-less block, a header, a diff, and an error's output.
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

        PATCH = <<~DIFF
           class Invoice < ApplicationRecord
          -  scope :settled, -> { where(status: "settled") }
          +  scope :settled, -> { where(status: :settled) }
          +  scope :overdue, -> { where(due_on: ...Date.current) }
           end
        DIFF

        def default
          render_component(code: RUBY_SAMPLE, language: "ruby", label: "Invoice model")
        end

        # CSS-counter line numbers (never in copied text) and the theme's
        # highlighted-line tint on the named lines.
        def numbered_and_highlighted
          render_component(code: RUBY_SAMPLE, language: "ruby", label: "Invoice model",
                           line_numbers: true, highlight_lines: [5, 7, 8, 9])
        end

        def without_copy
          render_component(code: %(export POETRY_THEME=vega\nbin/rake test:visual), language: "shell",
                           label: "Gate commands", copy: false)
        end

        # A title opens the header; the copy button moves into it.
        def with_header
          render_component(code: RUBY_SAMPLE, language: "ruby") do |block|
            block.with_title { "app/models/invoice.rb" }
          end
        end

        # A unified diff: the theme tints the lines and draws the markers.
        def diff
          render_component(code: PATCH, language: "ruby", diff: true) do |block|
            block.with_title { "app/models/invoice.rb" }
          end
        end

        # An error's output in the small size, with a footer.
        def destructive
          output = "Error: undefined method 'sum' for nil\n  app/models/invoice.rb:8:in 'total'"
          render_component(code: output, variant: :destructive, size: :sm, wrap: true, label: "Error output") do |block|
            block.with_footer { "Exited with status 1" }
          end
        end
      end
    end
  end
end
