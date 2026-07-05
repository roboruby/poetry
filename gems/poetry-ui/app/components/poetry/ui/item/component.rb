# frozen_string_literal: true

module Poetry
  module Ui
    module Item
      # The Item - the generic list row (Empty's sibling): media, a
      # title/description content column, and trailing actions, with
      # variant (default/outline/muted) and density (default/sm/xs).
      # Rows stack inside poetry_item_group (role=list) separated by
      # poetry_item_separator. Renders as a div by default; pass tag: :a
      # (+ href via passthrough) for a fully-clickable row.
      class Component < Poetry::Core::Component
        VARIANTS = %i[default outline muted].freeze
        SIZES = %i[default sm xs].freeze
        MEDIA_VARIANTS = %i[default icon image].freeze

        AGENT_RULES = [
          "Rows live inside poetry_item_group (role=list) and each row passes role: \"listitem\" - " \
          "a role=list parent with roleless children fails aria-required-children.",
          "Separate grouped rows with poetry_item_separator.",
          "Compose with the slots (media/title/description/actions); loose content lands in the " \
          "content column after the description.",
          "media_variant: :icon for a glyph, :image for a thumbnail (sized/rounded automatically).",
          "A clickable row is tag: :a with href: - never wrap an Item in a bare <a>."
        ].freeze

        option :tag, :symbol, default: :div
        option :media_variant, :symbol, default: :default

        # The variant/size axes are STYLE attributes (the Badge/Button DSL) -
        # they compose the dictionary's variant classes into the root class.
        style :variant, default: :default, required: true, variants: VARIANTS
        style :size, default: :default, required: true, variants: SIZES

        validates :media_variant, inclusion: { in: MEDIA_VARIANTS }

        renders_one :media
        renders_one :title
        renders_one :description
        renders_one :actions
        renders_one :header
        renders_one :footer

        def content_column?
          title? || description? || content.present?
        end

        def media_classes
          "#{css(:media)} #{css(:"media_#{media_variant}")}".strip
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "item", "data-variant" => variant, "data-size" => size
            }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
