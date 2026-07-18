# frozen_string_literal: true

module Poetry
  module Ui
    module Table
      # The Table preview: the shadcn table-demo (recent invoices) with a
      # caption, a footer total, and a selected row. Built with the same
      # data-slot + Style parts the poetry_table_* helpers stamp (the
      # helpers themselves are covered by the components-helper drift test).
      class Preview < Poetry::Core::Preview::Base
        ROWS = [
          ["INV001", "Paid", "$250.00", true],
          ["INV002", "Pending", "$150.00", false],
          ["INV003", "Unpaid", "$350.00", false],
          ["INV004", "Paid", "$500.00", false]
        ].freeze

        STATUSES = %w[Paid Pending Unpaid].freeze

        def default
          render_component do
            safe_join([caption, header, body, footer])
          end
        end

        # sticky_header pins the thead while the capped container scrolls
        # - enough rows to overflow the max-h-56 cap.
        def sticky
          render_component(sticky_header: true, container_class: "max-h-56") do
            safe_join([header, long_body])
          end
        end

        private

        def caption
          part(:caption, :caption, "table-caption") { "A list of your recent invoices." }
        end

        def header
          part(:thead, :header, "table-header") do
            row do
              safe_join([head { "Invoice" }, head { "Status" }, head(class: "text-right") { "Amount" }])
            end
          end
        end

        def body
          part(:tbody, :body, "table-body") do
            safe_join(ROWS.map do |invoice, status, amount, selected|
              row(data: selected ? { slot: "table-row", selected: "" } : { slot: "table-row" }) do
                safe_join([
                            cell(class: "font-medium") { invoice },
                            cell { status },
                            cell(class: "text-right") { amount }
                          ])
              end
            end)
          end
        end

        def footer
          part(:tfoot, :footer, "table-footer") do
            row { safe_join([cell(colspan: 2) { "Total" }, cell(class: "text-right") { "$1,250.00" }]) }
          end
        end

        def long_body
          part(:tbody, :body, "table-body") do
            safe_join((1..12).map do |i|
              row do
                safe_join([
                            cell(class: "font-medium") { format("INV%03d", i) },
                            cell { STATUSES[i % 3] },
                            cell(class: "text-right") { format("$%d50.00", i) }
                          ])
              end
            end)
          end
        end

        # tag.<el> with the Style class + data-slot - what the helper emits.
        def part(tag_name, element, slot, **attrs, &)
          classes = [Style.css(element), attrs.delete(:class)].compact.join(" ")
          data = attrs.delete(:data) || { slot: slot }
          content_tag(tag_name, capture(&), **attrs, class: classes, data: data)
        end

        def row(**attrs, &) = part(:tr, :row, "table-row", **attrs, &)
        def head(**attrs, &) = part(:th, :head, "table-head", **attrs, &)
        def cell(**attrs, &) = part(:td, :cell, "table-cell", **attrs, &)
      end
    end
  end
end
