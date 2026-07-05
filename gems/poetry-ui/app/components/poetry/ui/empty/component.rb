# frozen_string_literal: true

module Poetry
  module Ui
    module Empty
      # The Empty state - what a collection shows when there is nothing in
      # it: an optional media glyph, a title, a description, and the actions
      # that fix the emptiness (the content block). Slots compose the header;
      # the content block becomes empty-content.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "An empty collection gets an Empty state with a next action - never a bare 'No results' div.",
          "Compose with the slots (media/title/description); the actions are the content block.",
          "The title renders as a real heading (h3 default) - set title_tag: to fit the page outline.",
          "media_variant: :icon gives the rounded muted icon tile; wrap a poetry_icon in with_media."
        ].freeze

        # A real HEADING (h3 by default) - the same deliberate a11y
        # improvement over shadcn's div as Card's title (2026-07-01);
        # visual classes unchanged, so parity holds.
        option :title_tag, :symbol, default: :h3
        option :media_variant, :symbol, default: :default

        validates :title_tag, inclusion: { in: %i[h1 h2 h3 h4 h5 h6] }
        validates :media_variant, inclusion: { in: %i[default icon] }

        renders_one :media
        renders_one :title
        renders_one :description

        def header?
          media? || title? || description?
        end

        def media_classes
          variant = media_variant == :icon ? :media_icon : :media_default
          "#{css(:media)} #{css(variant)}"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "empty" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
