# frozen_string_literal: true

module Poetry
  module Ui
    # Labeled facts about one record, as a description list.
    module MetadataList
      # Labeled facts about one record - a real description list (<dl>)
      # for detail pages, in one or more columns, with each label above
      # its value (vertical) or beside it (horizontal). Values compose
      # freely: text, a Badge, a Link, a Timestamp.
      #
      # @example A record's fact sheet
      #   render Poetry::Ui::MetadataList::Component.new(columns: :two) do |list|
      #     list.with_item(label: "Status") { "Active" }
      #     list.with_item(label: "Owner") { "Ada Lovelace" }
      #   end
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Record facts on a detail page belong in a MetadataList - never a hand-rolled grid of " \
          "label/value divs (this is the <dl> the page owes its readers).",
          "Each with_item takes label: and the value as its block - values compose freely " \
          "(text, a Badge, a Link, a Timestamp).",
          "columns: :two / :three spread the facts on wide viewports; orientation: :horizontal " \
          "puts labels beside values (the classic key/value sheet) - pick one per surface.",
          "For editable facts pair each value with its edit affordance inside the item block; " \
          "the list itself stays read-only vocabulary."
        ].freeze

        # Slots the component cannot render without; static checks read this without rendering.
        REQUIRED_SLOTS = { item: "at least one item (label: plus the value block)" }.freeze

        renders_many :items,
                     doc: "The facts. Each takes label: (the fact's name, the <dt>) and the value as its block (the " \
                          "<dd>).",
                     renders: lambda { |label:, **options, &block|
                       # class: merges through the dictionary (caller classes win on
                       # conflicts) - a plain hash merge would REPLACE css(:item).
                       item_class = css(:item, class: options.delete(:class))
                       content_tag(:div, { "data-slot" => "metadata-list-item", class: item_class }.merge(options)) do
                         safe_join([
                                     content_tag(:dt, label, "data-slot" => "metadata-list-label", class: css(:label)),
                                     content_tag(:dd, { "data-slot" => "metadata-list-value", class: css(:value) },
                                                 &block)
                                   ])
                       end
                     }

        style :orientation, default: :vertical, variants: %i[vertical horizontal],
                            doc: "Label placement - above the value, or beside it for the classic key/value sheet."
        style :columns, default: :one, variants: %i[one two three],
                        doc: "How many columns the facts spread across on wide viewports."

        part "metadata-list", "The <dl> root - the record's fact sheet",
             states: {
               "data-orientation" => { condition: "always - label placement",
                                       values: %w[vertical horizontal] },
               "data-columns" => { condition: "always - the column count word",
                                   values: %w[one two three] }
             }
        part "metadata-list-item", "One fact group (a <div> holding its <dt>/<dd> pair)"
        part "metadata-list-label", "The fact's name (<dt>) - muted, small"
        part "metadata-list-value", "The fact's value (<dd>) - composes text, badges, links"

        # Enforces the required item slot.
        # @api private
        def before_render
          raise ArgumentError, "MetadataList requires at least one with_item" unless items?
        end

        # @api private
        def call
          content_tag(:dl, safe_join(items.map(&:to_s)), **root_attributes.to_attributes)
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "metadata-list", "data-orientation" => orientation,
              "data-columns" => columns }.merge(component_data_attributes)
          )
        end

        private :root_attributes
      end
    end
  end
end
