# frozen_string_literal: true

module Poetry
  module Ui
    module MetadataList
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |list|
            list.with_item(label: "Status") { "Active" }
            list.with_item(label: "Owner") { "Ada Lovelace" }
            list.with_item(label: "Created") { "June 12, 2026" }
          end
        end

        def two_columns
          render_component(columns: :two) do |list|
            list.with_item(label: "Invoice") { "INV-0042" }
            list.with_item(label: "Amount") { "$1,250.00" }
            list.with_item(label: "Due") { "July 31, 2026" }
            list.with_item(label: "Method") { "ACH transfer" }
          end
        end

        def horizontal
          render_component(orientation: :horizontal) do |list|
            list.with_item(label: "Environment") { "production" }
            list.with_item(label: "Region") { "us-east-1" }
            list.with_item(label: "Version") { "2.14.0" }
          end
        end

        def three_columns
          render_component(columns: :three) do |list|
            list.with_item(label: "CPU") { "42%" }
            list.with_item(label: "Memory") { "3.1 GB" }
            list.with_item(label: "Disk") { "58%" }
            list.with_item(label: "Region") { "us-east-1" }
            list.with_item(label: "Uptime") { "14 days" }
            list.with_item(label: "Status") { "Healthy" }
          end
        end

        # Values compose: a status Badge inside the <dd>.
        def composed_values
          render_component(columns: :two) do |list|
            list.with_item(label: "Status") do
              embed(Poetry::Ui::Badge::Component.new(variant: :success).with_content("Fulfilled"))
            end
            list.with_item(label: "Tracking") { "1Z 999 AA1 01" }
          end
        end
      end
    end
  end
end
