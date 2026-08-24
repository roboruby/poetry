# frozen_string_literal: true

module Poetry
  module Ui
    # DataTable family: the sortable, filterable, paginated table plus
    # its URL-state object.
    module DataTable
      # A data table: the composed Table with sortable column headers, a
      # filter box, and Pagination, where sort/filter/page live in the
      # URL as query params - shareable and back-button-correct. Data
      # stays with the host: the controller builds a sanitized State from
      # params, runs its own scope, and hands the page of rows in.
      # Row-level mutation (inline edit, row actions) belongs to reactive
      # components rendered inside cells, never to this component.
      #
      # @example A sortable notes table
      #   <%= poetry_data_table(rows: @notes, state: state, total: @pages,
      #                         path: ->(p) { notes_path(**p) }, caption: "Notes") do |t| %>
      #     <% t.with_column("Title", key: :title, sortable: true) { |note| note.title } %>
      #     <% t.with_column("Created", key: :created_at, sortable: true) { |note| note.created_at.to_date } %>
      #   <% end %>
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Build State.from_params(params, sortable: [...]) in the controller - NEVER order by raw params; " \
          "the whitelist is what makes state.order_clause injection-safe.",
          "Column cell blocks RETURN the cell content ({ |row| row.title }) - they must not write to the " \
          "template buffer.",
          "Sort/filter/page are URL state over GET links and a GET form. Row mutations (inline edit, row " \
          "actions) belong to poetry-reactive components rendered inside cells - never to this component.",
          "Give the table a caption: - it is the table's accessible purpose."
        ].freeze

        # The cell block is a per-row RENDERER, not captured content: it
        # receives each row record (SLOT_BLOCK_YIELDS exempts it from the
        # yieldless contract), and a column cannot exist without one.
        SLOT_BLOCK_YIELDS = { column: "the row record" }.freeze
        # Slots whose block content is required, with the hint the check surfaces.
        SLOT_REQUIRED_CONTENT = { column: "the cell renderer - { |row| ... }" }.freeze

        # The required slots, stated statically so static checks can flag
        # a missing column without rendering.
        REQUIRED_SLOTS = { column: "at least one column" }.freeze

        slot_doc :columns, "Columns are DECLARED here and rendered per row by the template. A sortable column's key " \
                           "must be in the state's whitelist - catching drift between the view's columns and the " \
                           "controller's sortable: list at render, not as a silently unsortable header."
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

        # The whole selection surface is selectable?-gated.
        use_stimulus do
          on :root, if: :selectable? do
            controller :table_selection do
              register
              value :label, from: :selected_count_label
            end
          end
          on :select_all do
            controller :table_selection do
              target :all
              action :toggleAll, on: :change
            end
          end
          on :row_checkbox do
            controller :table_selection do
              action :press, on: %i[pointerdown keydown]
              action :toggled, on: :change
            end
          end
        end

        option :caption, :string, doc: "The table's accessible purpose, rendered as its <caption>."
        option :empty_text, :string, default: "No results.", doc: "Shown in a full-width row when rows are empty."
        option :filter, :boolean, default: true, doc: "Renders the filter form; false drops the toolbar row."
        option :filter_label, :string, default: "Filter", doc: "The filter input's accessible label."
        option :filter_placeholder, :string, default: "Filter…", doc: "The filter input's placeholder text."
        option :filter_name, :string, default: "q", doc: "The query-param key the filter submits under."
        option :frame, :string,
               doc: "Wrap in a <turbo-frame data-turbo-action=\"advance\"> so hosts with Turbo scope the round trip " \
                    "to the table while the URL still advances. The host response must render the same frame id."
        option :sticky_header, :boolean, default: false,
                                         doc: "Forwarded to the inner Table: sticky_header pins the thead while the " \
                                              "table's scroll container scrolls; container_class caps that " \
                                              "container's height (\"max-h-96\") - without a cap nothing sticks. The " \
                                              "sticky scroll region needs an accessible name (the ScrollArea rule); " \
                                              "scroll_label: falls back to caption:."
        option :container_class, :string,
               doc: "Caps the scroll container's height (e.g. \"max-h-96\") - without a cap the sticky header has " \
                    "nothing to stick inside."
        option :scroll_label, :string, doc: "Accessible name for the sticky scroll region; falls back to caption:."
        option :selectable, ActiveModel::Type::Value.new,
               doc: "Row selection: a lambda mapping each row to its id turns the feature ON - a leading checkbox " \
                    "column (select-all with a real indeterminate middle state, shift ranges, count announcements) " \
                    "whose checkboxes ARE the form value (selection_name[], plain checkboxes with no JS). Pair with " \
                    "the action-bar block for bulk actions."
        option :selection_name, :string, default: "selected_ids",
                                         doc: "The checkbox field name; selected row ids post as selection_name[]."

        part "data-table", "Root surface - toolbar, table, and pagination footer stack here"
        part "data-table-toolbar", "The row above the table holding the filter form - " \
                                   "renders unless filter: false"
        part "data-table-filter", "The GET filter form (role=search) - hidden fields carry the " \
                                  "current sort; a new filter resets the page"
        part "table-container", "The composed Table's scroll container - Table renders it, " \
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

        # The structural collaborators handed in at construction.
        # @api private
        attr_reader :rows, :state, :total

        # Enforces at least one declared column.
        # @api private
        def before_render
          raise ArgumentError, "DataTable requires at least one with_column" unless columns?
        end

        # The declared columns in order.
        # @api private
        def column_defs
          @column_defs ||= []
        end

        # Attributes for the root surface.
        # @api private
        def root_attributes
          attrs = { "data-slot" => "data-table" }.merge(component_data_attributes)
          attrs = attrs.merge(stimulus_attributes_for(:root))
          html_attributes.merge_if_not_set(attrs)
        end

        # Whether row selection is on (selectable: present).
        # @api private
        def selectable?
          selectable.present?
        end

        # Attributes for the select-all header checkbox.
        # @api private
        def select_all_attributes
          {
            "type" => "checkbox", "data-slot" => "data-table-select-all",
            "class" => css(:checkbox),
            "aria-label" => t("poetry.data_table.select_all")
          }.merge(stimulus_attributes_for(:select_all))
        end

        # Attributes for one row's selection checkbox - the form value.
        # @api private
        def select_row_attributes(row)
          {
            "type" => "checkbox", "data-slot" => "data-table-select-row",
            "name" => "#{selection_name}[]", "value" => selectable.call(row),
            "class" => css(:checkbox),
            "aria-label" => t("poetry.data_table.select_row")
          }.merge(stimulus_attributes_for(:row_checkbox))
        end

        # The localized count-announcement template.
        # @api private
        def selected_count_label = t("poetry.data_table.selected_count")

        # Builds a URL for the given state params via the path: lambda.
        # @api private
        def path_for(params)
          @path.call(params)
        end

        # th attributes: the Table head classes plus aria-sort on the
        # actively sorted column (the APG announcement mechanism - one
        # column at a time).
        # @api private
        def head_attributes(column)
          attrs = { "data-slot" => "table-head", class: merge_classes(Table::Style.css(:head), column.classes) }
          if column.sortable && state.sorted_by?(column.key)
            attrs["aria-sort"] = state.dir == "asc" ? "ascending" : "descending"
          end
          attrs
        end

        # td attributes for one column's cells.
        # @api private
        def cell_attributes(column)
          { "data-slot" => "table-cell", class: merge_classes(Table::Style.css(:cell), column.classes) }
        end

        # The sort affordance: a ghost Button-styled LINK to the toggled
        # ordering (a real href - keyboard, middle-click, and share all work).
        # @api private
        def sort_link_options(column)
          {
            tag: :a, href: path_for(state.toggle_params(column.key)),
            variant: :ghost, size: :sm, class: Style.css(:sort_link),
            data: { slot: "data-table-sort" }
          }
        end

        # The header glyph for a column's current sort state.
        # @api private
        def sort_icon(column)
          return :"arrow-up-down" unless state.sorted_by?(column.key)

          state.dir == "asc" ? :"arrow-up" : :"arrow-down"
        end

        # The filter input's id (the label's for= target).
        # @api private
        def filter_id
          @filter_id ||= "#{poetry_instance_id("poetry-data-table")}-filter"
        end

        # The filter form's action is the bare collection URL; the current
        # sort rides hidden fields and the page deliberately resets (a new
        # filter is a new list).
        # @api private
        def filter_form_action
          path_for({})
        end

        # Whether the pagination footer renders (total: > 1 page).
        # @api private
        def pagination?
          total.present? && total > 1
        end

        # A declared column: header label, the whitelisted sort key, and the
        # cell block (called per row, returns the cell content).
        # @api private
        Column = Data.define(:label, :key, :sortable, :classes, :cell)

        private

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

        private :column_defs, :root_attributes, :selectable?, :select_all_attributes, :select_row_attributes
        private :selected_count_label, :path_for, :head_attributes, :cell_attributes, :sort_link_options, :sort_icon
        private :filter_id, :filter_form_action, :pagination?
      end
    end
  end
end
