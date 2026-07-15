# frozen_string_literal: true

module Poetry
  module Ui
    module DataTable
      # The DataTable - a server-driven recipe-as-component: the W1 Table
      # with sortable column headers, a filter box, and Pagination, with
      # sort/filter/page as URL STATE (shareable, back-button-correct; GET is
      # the only transport the back button can replay). Data stays with the
      # host: the controller builds a sanitized State from params, runs
      # its own scope, and hands the page of rows in. Row-level mutation
      # (inline edit, row actions) belongs to the reactive tier
      # (poetry-reactive) - each tier owns the state that belongs to it.
      #
      #   <%= poetry_data_table(rows: @notes, state: state, total: @pages,
      #                         path: ->(p) { notes_path(**p) }, caption: "Notes") do |t| %>
      #     <% t.with_column("Title", key: :title, sortable: true) { |note| note.title } %>
      #     <% t.with_column("Created", key: :created_at, sortable: true) { |note| note.created_at.to_date } %>
      #   <% end %>
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Build State.from_params(params, sortable: [...]) in the controller - NEVER order by raw params; " \
          "the whitelist is what makes state.order_clause injection-safe.",
          "Column cell blocks RETURN the cell content ({ |row| row.title }) - they must not write to the " \
          "template buffer.",
          "Sort/filter/page are URL state over GET links and a GET form. Row mutations (inline edit, row " \
          "actions) belong to poetry-reactive components rendered inside cells - never to this component.",
          "Give the table a caption: - it is the table's accessible purpose."
        ].freeze

        # A declared column: header label, the whitelisted sort key, and the
        # cell block (called per row, returns the cell content).
        Column = Data.define(:label, :key, :sortable, :classes, :cell)
        SELECTION = %i[poetry core table_selection].freeze

        option :caption, :string
        option :empty_text, :string, default: "No results."
        option :filter, :boolean, default: true
        option :filter_label, :string, default: "Filter"
        option :filter_placeholder, :string, default: "Filter…"
        option :filter_name, :string, default: "q"
        # Wrap in a <turbo-frame data-turbo-action="advance"> so hosts with
        # Turbo scope the round trip to the table while the URL still
        # advances. The host response must render the same frame id.
        option :frame, :string
        # Row selection: a lambda mapping each row to its id turns
        # the feature ON - a leading checkbox column (select-all with a
        # real indeterminate middle state, shift ranges, count
        # announcements) whose checkboxes ARE the form value
        # (selection_name[], plain checkboxes with no JS). Pair with the
        # action-bar block for bulk actions.
        option :selectable, ActiveModel::Type::Value.new
        option :selection_name, :string, default: "selected_ids"

        part "data-table", "Root surface - toolbar, table, and pagination footer stack here"
        part "data-table-toolbar", "The row above the table holding the filter form - " \
                                   "renders unless filter: false"
        part "data-table-filter", "The GET filter form (role=search) - hidden fields carry the " \
                                  "current sort; a new filter resets the page"
        part "table-container", "The composed W1 Table's scroll container - Table renders it, " \
                                "this surface owns where it sits"
        part "data-table-footer", "The Pagination row - renders when total: is more than one page"
        # The selection checkboxes (selectable: only) render INSIDE the
        # composed Table's root, so ownership attributes them to Table
        # (the NumberField-stepper precedent) - prose, not parts:
        # data-slot="data-table-select-all" is the header checkbox (the
        # controller drives its INDETERMINATE middle state as a property);
        # data-slot="data-table-select-row" is one row's checkbox - THE
        # form value (selection_name[], value from the selectable: lambda);
        # the controller mirrors aria-selected/data-selected onto rows.

        # The cell block is a per-row RENDERER, not captured content: it
        # receives each row record (SLOT_BLOCK_YIELDS exempts it from the
        # yieldless contract), and a column cannot exist without one.
        SLOT_BLOCK_YIELDS = { column: "the row record" }.freeze
        SLOT_REQUIRED_CONTENT = { column: "the cell renderer - { |row| ... }" }.freeze

        # Columns are DECLARED here and rendered per row by the template. A
        # sortable column's key must be in the state's whitelist - catching
        # drift between the view's columns and the controller's sortable:
        # list at render, not as a silently unsortable header.
        renders_many :columns, lambda { |label, key: nil, sortable: false, classes: nil, &cell|
          raise ArgumentError, "DataTable column #{label.inspect}: sortable: true requires a key:" if sortable && !key
          if sortable && !state.sortable?(key)
            raise ArgumentError,
                  "DataTable column #{key.inspect} is sortable in the view but missing from the " \
                  "controller's State sortable: whitelist (#{state.sortable.inspect}) - add it there"
          end
          raise ArgumentError, "DataTable column #{label.inspect} requires a cell block" unless cell

          column_defs << Column.new(label: label, key: key&.to_s, sortable: sortable, classes: classes, cell: cell)
          nil
        }

        attr_reader :rows, :state, :total

        def column_defs
          @column_defs ||= []
        end

        # The same facts the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering (the
        # menu crash class - required slots the contract kept silent).
        REQUIRED_SLOTS = { column: "at least one column" }.freeze

        def before_render
          raise ArgumentError, "DataTable requires at least one with_column" unless columns?
        end

        def root_attributes
          attrs = { "data-slot" => "data-table" }.merge(component_data_attributes)
          attrs = attrs.merge(selection_stimulus_attributes) if selectable?
          html_attributes.merge_if_not_set(attrs)
        end

        def selectable?
          selectable.present?
        end

        def select_all_attributes
          {
            "type" => "checkbox", "data-slot" => "data-table-select-all",
            "class" => css(:checkbox),
            "aria-label" => t("poetry.data_table.select_all"),
            "data-poetry--core--table-selection-target" => "all",
            "data-action" => "change->poetry--core--table-selection#toggleAll"
          }
        end

        def select_row_attributes(row)
          {
            "type" => "checkbox", "data-slot" => "data-table-select-row",
            "name" => "#{selection_name}[]", "value" => selectable.call(row),
            "class" => css(:checkbox),
            "aria-label" => t("poetry.data_table.select_row"),
            "data-action" => "pointerdown->poetry--core--table-selection#press " \
                             "keydown->poetry--core--table-selection#press " \
                             "change->poetry--core--table-selection#toggled"
          }
        end

        def path_for(params)
          @path.call(params)
        end

        # th attributes: the W1 Table head classes plus aria-sort on the
        # actively sorted column (the APG announcement mechanism - one
        # column at a time).
        def head_attributes(column)
          attrs = { "data-slot" => "table-head", class: merge_classes(Table::Style.css(:head), column.classes) }
          if column.sortable && state.sorted_by?(column.key)
            attrs["aria-sort"] = state.dir == "asc" ? "ascending" : "descending"
          end
          attrs
        end

        def cell_attributes(column)
          { "data-slot" => "table-cell", class: merge_classes(Table::Style.css(:cell), column.classes) }
        end

        # The sort affordance: a ghost Button-styled LINK to the toggled
        # ordering (a real href - keyboard, middle-click, and share all work).
        def sort_link_options(column)
          {
            tag: :a, href: path_for(state.toggle_params(column.key)),
            variant: :ghost, size: :sm,
            data: { slot: "data-table-sort" }
          }
        end

        def sort_icon(column)
          return :"arrow-up-down" unless state.sorted_by?(column.key)

          state.dir == "asc" ? :"arrow-up" : :"arrow-down"
        end

        def filter_id
          @filter_id ||= "poetry-data-table-#{SecureRandom.hex(4)}-filter"
        end

        # The filter form's action is the bare collection URL; the current
        # sort rides hidden fields and the page deliberately resets (a new
        # filter is a new list).
        def filter_form_action
          path_for({})
        end

        def pagination?
          total.present? && total > 1
        end

        private

        def selection_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          selection = Poetry::Core::Stimulus::Builder.new(SELECTION, attrs)
          selection.register_controller
          selection.with_value(:label, t("poetry.data_table.selected_count"))
          attrs.to_attributes
        end

        # rows/state/path/total are structural collaborators, not typed
        # options (see Pagination's path: for the precedent).
        def initialize(rows:, state:, path:, total: nil, **)
          super(**)
          @rows = rows
          @state = state
          @path = path
          @total = total
        end

        def merge_classes(*values)
          values.compact.join(" ")
        end
      end
    end
  end
end
