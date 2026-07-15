# frozen_string_literal: true

module Poetry
  module Ui
    module DataTable
      # The DataTable preview: a small invoices dataset in the three states
      # a host sees - sorted, filtered+paginated, and empty.
      class Preview < Poetry::Core::Preview::Base
        Invoice = Struct.new(:number, :customer, :amount, keyword_init: true)

        ROWS = [
          Invoice.new(number: "INV-001", customer: "Acme", amount: "$250.00"),
          Invoice.new(number: "INV-002", customer: "Globex", amount: "$1,150.00"),
          Invoice.new(number: "INV-003", customer: "Initech", amount: "$420.00")
        ].freeze

        def default
          render_component(rows: ROWS, state: state(sort: "number", dir: "asc"),
                           path: path, caption: "A list of recent invoices.") do |table|
            columns(table)
          end
        end

        # Row selection: selectable: maps rows to ids; the header
        # checkbox tri-states, shift-click ranges, the checkboxes ARE the
        # selected_ids[] form value. Pair with the action-bar block.
        def selectable
          render_component(rows: ROWS, state: state(sort: "number", dir: "asc"),
                           path: path, caption: "A list of recent invoices.",
                           selectable: ->(invoice) { invoice.number }) do |table| # rubocop:disable Style/SymbolProc
            columns(table)
          end
        end

        def filtered_and_paginated
          render_component(rows: ROWS.first(2), total: 3,
                           state: state(q: "inv", sort: "customer", dir: "desc", page: 2),
                           path: path, caption: "A list of recent invoices.") do |table|
            columns(table)
          end
        end

        def empty
          render_component(rows: [], state: state(q: "zzz"), path: path,
                           caption: "A list of recent invoices.") do |table|
            columns(table)
          end
        end

        private

        def columns(table)
          table.with_column("Invoice", key: :number, sortable: true, &:number)
          table.with_column("Customer", key: :customer, sortable: true, &:customer)
          table.with_column("Amount", classes: "text-right", &:amount)
        end

        def state(**params)
          State.from_params(params, sortable: %w[number customer])
        end

        def path
          ->(params) { "?#{params.to_query}" }
        end
      end
    end
  end
end
