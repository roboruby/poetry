# frozen_string_literal: true

module Poetry
  module Ui
    module DataTable
      # The DataTable's URL state - sort/filter/page as query params
      # (shareable, back-button-correct), sanitized at the door so request
      # params can never reach an ORDER BY. `sort` is kept ONLY when it
      # appears in the `sortable:` whitelist and `dir` only when it is
      # asc/desc - so #order_clause is safe by construction, never by
      # caller discipline.
      #
      # @example Building state in the controller
      #   state = Poetry::Ui::DataTable::State.from_params(
      #     params, sortable: %w[title created_at], default_sort: "created_at", default_dir: "desc"
      #   )
      #   scope = Note.all
      #   scope = scope.where("title LIKE ?", "%#{Note.sanitize_sql_like(state.q)}%") if state.q
      #   notes = scope.order(state.order_clause).offset(...).limit(per)
      class State
        DIRECTIONS = %w[asc desc].freeze

        attr_reader :q, :sort, :dir, :page, :sortable

        def self.from_params(params, sortable:, default_sort: nil, default_dir: "asc")
          allowed = Array(sortable).map(&:to_s)
          raw_sort = params[:sort].to_s
          raw_dir = params[:dir].to_s

          new(
            q: params[:q].to_s.strip.presence,
            sort: allowed.include?(raw_sort) ? raw_sort : default_sort&.to_s,
            dir: DIRECTIONS.include?(raw_dir) ? raw_dir : default_dir.to_s,
            page: [params[:page].to_i, 1].max,
            sortable: allowed
          )
        end

        def initialize(q: nil, sort: nil, dir: "asc", page: 1, sortable: [])
          @q = q
          @sort = sort
          @dir = dir
          @page = page
          @sortable = sortable
        end

        def sortable?(column)
          sortable.include?(column.to_s)
        end

        def sorted_by?(column)
          sort == column.to_s
        end

        # Injection-safe by construction: sort survived the whitelist and dir
        # the asc/desc check, so this can go straight into .order(). Nil when
        # nothing is sorted.
        def order_clause
          return nil unless sort

          { sort => dir.to_sym }
        end

        # The full state as query params (blank pieces omitted; page 1 is the
        # default and stays out of the URL).
        def to_params
          params = {}
          params[:q] = q if q
          if sort
            params[:sort] = sort
            params[:dir] = dir
          end
          params[:page] = page if page > 1
          params
        end

        # Params for clicking a sortable header: same column flips the
        # direction, a new column starts ascending; the page resets (a new
        # ordering is a new list).
        def toggle_params(column)
          column = column.to_s
          next_dir = sorted_by?(column) && dir == "asc" ? "desc" : "asc"
          to_params.except(:page).merge(sort: column, dir: next_dir)
        end

        # Params for navigating to a page of the current view.
        def page_params(number)
          number > 1 ? to_params.merge(page: number) : to_params.except(:page)
        end

        # The state a filter submission must carry as hidden fields: sort
        # survives, the page resets (a new filter is a new list), and q is
        # the form input itself.
        def filter_params
          to_params.except(:q, :page)
        end
      end
    end
  end
end
