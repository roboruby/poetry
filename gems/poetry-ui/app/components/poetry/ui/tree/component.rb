# frozen_string_literal: true

module Poetry
  module Ui
    module Tree
      # The Tree (the react-aria flat-treegrid contract): a
      # hierarchical expandable list - file navigators, nested categories,
      # org structures. The DOM is a FLAT list of role=row siblings;
      # hierarchy lives entirely in server-computed aria-level/posinset/
      # setsize (static per render), which is exactly what makes a
      # server-rendered tree viable - no nested group markup. Rows under a
      # collapsed ancestor render hidden; poetry--core--tree owns roving
      # focus over visible rows, the four-branch ArrowLeft/Right expansion
      # keys (ArrowLeft on a leaf walks to the PARENT), Enter/press
      # toggling, and typeahead. Expansion state IS the DOM - the host
      # persists it by listening for poetry:tree:toggle.
      #
      # Items build through a plain nested builder (not slots):
      #
      #   <%= poetry_tree(label: "Files") do |tree| %>
      #     <% tree.with_item(text: "docs", value: "docs", expanded: true) do |docs| %>
      #       <% docs.with_item(text: "intro.md", value: "intro", href: "/docs/intro") %>
      #     <% end %>
      #   <% end %>
      #
      # Documented divergence: selection modes are deferred (the TagGroup
      # reasoning) - v1 is navigation + expansion; href: items navigate.
      class Component < Poetry::Core::Component
        CONTROLLER = %i[poetry core tree].freeze

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

        # One flattened row (built by Item#flatten below).
        Row = Struct.new(
          :text, :value, :href, :level, :posinset, :setsize,
          :expanded, :expandable, :disabled, :hidden,
          keyword_init: true
        )

        # The nested builder handed to consumer blocks.
        class Item
          attr_reader :options, :children

          def initialize(**options)
            @options = options
            @children = []
          end

          def with_item(**)
            child = Item.new(**)
            @children << child
            yield child if block_given?
            child
          end
        end

        option :label, :string, required: true

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

        def with_item(**options, &block)
          root_items << Item.new(**options).tap { |item| block&.call(item) }
          nil
        end

        def root_items
          @root_items ||= []
        end

        def before_render
          raise ArgumentError, "Tree requires label: (the treegrid's accessible name)" if label.blank?

          # Consume the content block: it runs for its with_item side
          # effects (the builder API), never for output.
          content
        end

        def rows
          @rows ||= flatten(root_items, level: 1, hidden: false)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "tree", "role" => "treegrid",
              "aria-label" => label, "class" => css
            }.merge(component_data_attributes).merge(root_stimulus_attributes)
          )
        end

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
          attrs["data-disabled"] = "" if row.disabled
          attrs["hidden"] = "" if row.hidden
          attrs
        end

        def toggle_attributes(row, index)
          {
            "type" => "button", "tabindex" => "-1",
            "data-slot" => "tree-item-toggle", "class" => css(:toggle),
            "aria-label" => row.expanded ? t("poetry.tree.collapse") : t("poetry.tree.expand"),
            "aria-labelledby" => "#{row_id(index)}-toggle #{row_id(index)}",
            "id" => "#{row_id(index)}-toggle",
            "data-expand-label" => t("poetry.tree.expand"),
            "data-collapse-label" => t("poetry.tree.collapse")
          }.merge(toggle_stimulus_attributes)
        end

        def row_id(index)
          "#{tree_id}-item-#{index}"
        end

        def tree_id
          @tree_id ||= "poetry-tree-#{SecureRandom.hex(4)}"
        end

        def first_visible_index
          @first_visible_index ||= rows.index { |row| !row.hidden } || 0
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

        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          tree = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          tree.register_controller
          tree.with_action(:keydown, on: :keydown)
          tree.with_action(:press, on: :click)
          attrs.to_attributes
        end

        def toggle_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          tree = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          tree.with_action(:pressStart, on: :pointerdown)
          tree.with_action(:toggle, on: :click)
          attrs.to_attributes
        end
      end
    end
  end
end
