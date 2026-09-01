# frozen_string_literal: true

module Poetry
  module Ui
    # The Item family - the generic list row.
    module Item
      # The Item - the generic list row (Empty's sibling): media, a
      # title/description content column, and trailing actions, with
      # variant (default/outline/muted) and density (default/sm/xs).
      # Rows stack inside poetry_item_group (role=list) separated by
      # poetry_item_separator. Renders as a div by default; pass tag: :a
      # (+ href via passthrough) for a fully-clickable row.
      #
      # @example
      #   render Poetry::Ui::Item::Component.new(variant: :outline) do |item|
      #     item.with_title { "Backups" }
      #     item.with_description { "Nightly, retained 30 days" }
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the variant axis.
        VARIANTS = %i[default outline muted].freeze
        # The closed vocabulary for the size (density) axis.
        SIZES = %i[default sm xs].freeze
        # The closed vocabulary for the media_variant axis.
        MEDIA_VARIANTS = %i[default icon image].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Rows live inside poetry_item_group (role=list) and each row passes role: \"listitem\" - " \
          "a role=list parent with roleless children fails aria-required-children.",
          "Separate grouped rows with poetry_item_separator.",
          "Compose with the slots (media/title/description/actions); loose content lands in the " \
          "content column after the description.",
          "media_variant: :icon for a glyph, :image for a thumbnail (sized/rounded automatically).",
          "A clickable row is tag: :a with href: - never wrap an Item in a bare <a>."
        ].freeze

        renders_one :media, doc: "The leading media cell - a glyph or thumbnail (see media_variant)."
        renders_one :title, doc: "The title row."
        renders_one :description, doc: "The muted description line (clamps to two lines)."
        renders_one :actions, doc: "The trailing actions cell - buttons, a menu, a switch."
        renders_one :header, doc: "Full-width row above the media/content columns."
        renders_one :footer, doc: "Full-width row below the media/content columns."

        style :variant, default: :default, required: true, variants: VARIANTS,
                        doc: "The row's visual treatment - :outline boxes it, :muted recedes."
        style :size, default: :default, required: true, variants: SIZES, doc: "The row's density."

        option :tag, :symbol, default: :div,
                              doc: "The root element - tag: :a (href via passthrough) makes the whole row clickable."
        option :media_variant, :symbol, default: :default,
                                        doc: "The media treatment - :icon for a glyph, :image for a thumbnail."

        validates :media_variant, inclusion: { in: MEDIA_VARIANTS }

        part "item", "The row root (a div by default; tag: :a for a clickable row) - variant and " \
                     "density land here as data attributes",
             states: {
               "data-variant" => { condition: "the row's visual variant", values: VARIANTS.map(&:to_s) },
               "data-size" => { condition: "the row's density", values: SIZES.map(&:to_s) }
             }
        part "item-media", "The leading media cell - sized and rounded by its variant",
             states: {
               "data-variant" => { condition: "the media treatment", values: MEDIA_VARIANTS.map(&:to_s) }
             }
        part "item-content", "The center column collecting title, description, and loose content"
        part "item-title", "The title row"
        part "item-description", "The muted description line"
        part "item-header", "Full-width row above the media/content columns"
        part "item-actions", "The trailing actions cell"
        part "item-footer", "Full-width row below the media/content columns"

        # Whether the center column renders (title, description, or loose content).
        # @api private
        def content_column?
          title? || description? || content.present?
        end

        # The media cell's classes for the resolved media_variant.
        # @api private
        def media_classes
          "#{css(:media)} #{css(:"media_#{media_variant}")}".strip
        end

        # The row root's attributes.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "item", "data-variant" => variant, "data-size" => size
            }.merge(component_data_attributes)
          )
        end

        private :content_column?, :media_classes, :root_attributes
      end
    end
  end
end
