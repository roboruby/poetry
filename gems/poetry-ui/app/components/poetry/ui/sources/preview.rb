# frozen_string_literal: true

module Poetry
  module Ui
    module Sources
      # The Sources preview: the list closed behind its count, and open.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(class: "max-w-xl") { |sources| add(sources) }
        end

        # Open from the start: each source with its number, its site and
        # the passage it was cited for.
        def open
          render_component(open: true, class: "max-w-xl") { |sources| add(sources) }
        end

        private

        def add(sources)
          sources.with_source("Fulfilment guide", href: "https://example.com/fulfilment",
                                                  description: "Orders ship within two working days of payment.")
          sources.with_source("Refund policy", href: "https://example.com/refunds",
                                               description: "Refunds are issued within five working days.")
          sources.with_source("Warehouse handbook, section 4")
        end
      end
    end
  end
end
