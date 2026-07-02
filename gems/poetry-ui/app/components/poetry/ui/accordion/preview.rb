# frozen_string_literal: true

module Poetry
  module Ui
    module Accordion
      # The Accordion preview matrix.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(open: %w[shipping]) do |accordion|
            accordion.with_item(value: "shipping", title: "Shipping") { "Free over $50, worldwide." }
            accordion.with_item(value: "returns", title: "Returns") { "30 days, no questions." }
            accordion.with_item(value: "warranty", title: "Warranty") { "Two years, parts and labor." }
          end
        end

        def multiple
          render_component(type: :multiple, open: %w[a b]) do |accordion|
            accordion.with_item(value: "a", title: "First") { "Open together" }
            accordion.with_item(value: "b", title: "Second") { "with the first." }
          end
        end

        def single_collapsible
          render_component(collapsible: true, open: %w[only]) do |accordion|
            accordion.with_item(value: "only", title: "Toggle me") { "I can close." }
          end
        end
      end
    end
  end
end
