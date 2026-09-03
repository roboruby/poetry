# frozen_string_literal: true

module Poetry
  module Ui
    # Hierarchical expandable lists.
    module Tree
      # A hierarchical expandable list - file navigators, nested
      # categories, org structures. The DOM is a flat list of sibling
      # rows; hierarchy lives entirely in server-computed
      # aria-level/posinset/setsize, so no nested markup is needed and
      # the whole tree server-renders. Rows under a collapsed ancestor
      # render hidden. Arrow keys move over visible rows,
      # ArrowLeft/Right collapse and expand (ArrowLeft on a leaf walks to
      # the parent), Enter/press toggles, and typing jumps to a matching
      # row.
      #
      # Items build through a nested builder (see with_item). Expansion
      # state lives in the DOM - persist it by listening for
      # poetry:tree:toggle and re-rendering with expanded: from your
      # store. href: items navigate; a Tree offers no selection modes.
      #
      # @example
      #   <%= poetry_tree(label: "Files") do |tree| %>
      #     <% tree.with_item(text: "docs", value: "docs", expanded: true) do |docs| %>
      #       <% docs.with_item(text: "intro.md", value: "intro", href: "/docs/intro") %>
      #     <% end %>
      #   <% end %>
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Hierarchical expandable lists are a Tree - never hand-rolled nested <ul>s with " \
          "click handlers; the treegrid semantics, expansion keys, and focus rules ride the " \
          "controller.",
          "label: is REQUIRED (the treegrid's accessible name).",
          "Items: tree.with_item(text:, value:, expanded:, disabled:, href:) with nesting via " \
          "the block - the component flattens and computes aria-level/posinset/setsize.",
          "Expansion is client state; persist it by listening for poetry:tree:toggle and " \
          "re-rendering with expanded: from your store.",
          "Navigation destinations take href: (the label renders as a link); a Tree is not a " \
          "menu - actions belong to DropdownMenu, picking to Select/Combobox."
        ].freeze

        use_stimulus do
          on :root do
            controller :tree do
              register
              action :keydown, on: :keydown
              action :press, on: :click
            end
          end
          on :toggle do
            controller :tree do
              action :pressStart, on: :pointerdown
              action :toggle, on: :click
            end
          end
        end

        option :label, :string, required: true, doc: "The tree's accessible name. Required."

        part "tree", "The treegrid container (role=treegrid, the accessible name) - roving " \
                     "focus, expansion keys, and typeahead ride here; rows are FLAT siblings"
        part "tree-item", "One row (role=row > gridcell) - hierarchy in aria-level/posinset/" \
                          "setsize, indentation via --poetry-tree-level; rows under a " \
                          "collapsed ancestor render hidden",
             states: {
               "data-expanded" => "the row's subtree is open (parents only; aria-expanded " \
                                  "is the canonical twin)",
               "data-disabled" => "the item is disabled (skipped by arrows and typeahead)",
               "data-value" => { condition: "always - the toggle event's identity" },
               "data-level" => { condition: "always - the 1-based depth (aria-level's twin; " \
                                            "--poetry-tree-level drives the indent)" }
             },
             vars: {
               "--poetry-tree-level" => "the 1-based depth - indentation is " \
                                        "calc((level - 1) * step) in the dictionary"
             }
        part "tree-item-toggle", "The chevron (parents only): tabindex -1, never steals " \
                                 "focus, aria-label flips Expand/Collapse",
             states: {
               "data-expand-label" => "always - the localized Expand string the controller " \
                                      "swaps in on collapse",
               "data-collapse-label" => "always - the localized Collapse string the " \
                                        "controller swaps in on expand"
             }
        part "tree-item-label", "The row's text - a link when href: is given"

        # @api private
        def before_render
          raise ArgumentError, "Tree requires label: (the treegrid's accessible name)" if label.blank?

          # Consume the content block: it runs for its with_item side
          # effects (the builder API), never for output.
          content
        end

        # Declares one row. Nest children by calling with_item again on the
        # yielded builder. Keywords: text: (the row's label, required), value:
        # (the toggle event's identity, defaults to text:), expanded: (render
        # the subtree open), disabled:, href: (the label renders as a link).
        #
        # @example
        #   tree.with_item(text: "docs", value: "docs", expanded: true) do |docs|
        #     docs.with_item(text: "intro.md", href: "/docs/intro")
        #   end
        def with_item(**, &block)
          root_items << Item.new(**).tap { |item| block&.call(item) }
          nil
        end

        # @api private
        def root_items
          @root_items ||= []
        end

        # @api private
        def rows
          @rows ||= flatten(root_items, level: 1, hidden: false)
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "tree", "role" => "treegrid",
              "aria-label" => label, "class" => css
            }.merge(component_data_attributes).merge(stimulus_attributes_for(:root))
          )
        end

        # @api private
        def row_attributes(row, index)
          attrs = {
            "id" => row_id(index), "role" => "row", "data-slot" => "tree-item",
            "data-value" => row.value, "data-level" => row.level,
            "aria-level" => row.level, "aria-posinset" => row.posinset,
            "aria-setsize" => row.setsize,
            "tabindex" => index == first_visible_index ? "0" : "-1",
            "style" => "--poetry-tree-level: #{row.level}",
            "class" => css(:item)
          }
          attrs["aria-expanded"] = row.expanded.to_s if row.expandable
          attrs["data-expanded"] = "" if row.expandable && row.expanded
          if row.disabled
            attrs["data-disabled"] = ""
            attrs["aria-disabled"] = "true"
          end
          attrs["hidden"] = "" if row.hidden
          attrs
        end

        # @api private
        def toggle_attributes(row, index)
          {
            "type" => "button", "tabindex" => "-1",
            "data-slot" => "tree-item-toggle", "class" => css(:toggle),
            "aria-label" => row.expanded ? t("poetry.tree.collapse") : t("poetry.tree.expand"),
            "aria-labelledby" => "#{row_id(index)}-toggle #{row_id(index)}",
            "id" => "#{row_id(index)}-toggle",
            "data-expand-label" => t("poetry.tree.expand"),
            "data-collapse-label" => t("poetry.tree.collapse")
          }.merge(stimulus_attributes_for(:toggle))
        end

        # @api private
        def row_id(index)
          "#{tree_id}-item-#{index}"
        end

        # @api private
        def tree_id
          @tree_id ||= poetry_instance_id("poetry-tree")
        end

        # @api private
        def first_visible_index
          @first_visible_index ||= rows.index { |row| !row.hidden } || 0
        end

        # One flattened row (built by #flatten below).
        # @api private
        Row = Struct.new(
          :text, :value, :href, :level, :posinset, :setsize,
          :expanded, :expandable, :disabled, :hidden,
          keyword_init: true
        )

        # The nested builder yielded to item blocks - call with_item on it
        # to declare children. Never constructed directly.
        class Item
          # @api private
          attr_reader :options, :children

          # @api private
          def initialize(**options)
            @options = options
            @children = []
          end

          # Declares a child row; takes the same keywords as the
          # component's with_item and yields its own builder for nesting.
          def with_item(**)
            child = Item.new(**)
            @children << child
            yield child if block_given?
            child
          end
        end

        private

        def flatten(items, level:, hidden:)
          items.flat_map.with_index do |item, index|
            expandable = item.children.any?
            expanded = expandable && item.options.fetch(:expanded, false)
            row = Row.new(
              text: item.options.fetch(:text), value: item.options[:value] || item.options.fetch(:text),
              href: item.options[:href], level: level,
              posinset: index + 1, setsize: items.size,
              expanded: expanded, expandable: expandable,
              disabled: item.options.fetch(:disabled, false), hidden: hidden
            )

            [row] + flatten(item.children, level: level + 1, hidden: hidden || !expanded)
          end
        end

        private :root_items, :rows, :root_attributes, :row_attributes, :toggle_attributes, :row_id, :tree_id
        private :first_visible_index
      end
    end
  end
end
