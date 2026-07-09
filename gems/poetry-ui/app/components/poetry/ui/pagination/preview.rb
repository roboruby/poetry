# frozen_string_literal: true

module Poetry
  module Ui
    module Pagination
      # The Pagination preview: a middle page of a long range (both ellipses
      # show), a short range (every page, no truncation), and the first page
      # (Previous disabled).
      class Preview < Poetry::Core::Preview::Base
        PATH = ->(page) { "?page=#{page}" }

        def default
          render_component(current: 4, total: 10, path: PATH)
        end

        def long_range_both_ellipses
          render_component(current: 8, total: 20, path: PATH)
        end

        def short_range_no_truncation
          render_component(current: 2, total: 4, path: PATH)
        end

        def first_page
          render_component(current: 1, total: 10, path: PATH)
        end

        # The filled current-page treatment (Blocks v1.1): the primary
        # Button as the active marker - the data-index block's choice.
        def filled_current
          render_component(current: 4, total: 10, current_variant: :filled, path: PATH)
        end
      end
    end
  end
end
