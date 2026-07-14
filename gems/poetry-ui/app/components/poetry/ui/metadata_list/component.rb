# frozen_string_literal: true

module Poetry
  module Ui
    module MetadataList
      # The MetadataList - the detail-page vocabulary (, the
      # review add): labeled facts about one record as a real
      # description list (<dl>), in one or more columns, with the label
      # above the value (vertical) or beside it (horizontal). No upstream
      # shadcn/Base UI analogue; the anatomy follows an upstream MetadataList
      # on platform semantics. Styling is utility-only (the Separator/
      # Spinner rule): data-slot names are the restyle seam.
      class Component < Poetry::Core::Component
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

        style :orientation, default: :vertical, variants: %i[vertical horizontal]
        style :columns, default: :one, variants: %i[one two three]

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

        renders_many :items, lambda { |label:, **options, &block|
          content_tag(:div, { "data-slot" => "metadata-list-item", class: css(:item) }.merge(options)) do
            safe_join([
                        content_tag(:dt, label, "data-slot" => "metadata-list-label", class: css(:label)),
                        content_tag(:dd, { "data-slot" => "metadata-list-value", class: css(:value) }, &block)
                      ])
          end
        }

        # The same fact the before_render raise enforces, stated statically
        #: poetry check flags the omission without rendering.
        REQUIRED_SLOTS = { item: "at least one item (label: plus the value block)" }.freeze

        def before_render
          raise ArgumentError, "MetadataList requires at least one with_item" unless items?
        end

        def call
          content_tag(:dl, safe_join(items.map(&:to_s)), **root_attributes.to_attributes)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "metadata-list", "data-orientation" => orientation,
              "data-columns" => columns }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
