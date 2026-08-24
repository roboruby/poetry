# frozen_string_literal: true

module Poetry
  module Ui
    # The Empty family - the empty-state block for collections with nothing in them.
    module Empty
      # The Empty state - what a collection shows when there is nothing in
      # it: an optional media glyph, a title, a description, and the actions
      # that fix the emptiness (the content block). Slots compose the header;
      # the content block becomes empty-content.
      #
      # @example Empty collection with a next action
      #   render Poetry::Ui::Empty::Component.new do |empty|
      #     empty.with_title { "No projects yet" }
      #     empty.with_description { "Create your first project to get started." }
      #     poetry_button { "New project" }
      #   end
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "An empty collection gets an Empty state with a next action - never a bare 'No results' div.",
          "Compose with the slots (media/title/description); the actions are the content block.",
          "The title renders as a real heading (h3 default) - set title_tag: to fit the page outline.",
          "media_variant: :icon gives the rounded muted icon tile; wrap a poetry_icon in with_media."
        ].freeze

        # Optional leading visual above the title - an icon or illustration.
        renders_one :media
        # The headline, rendered as a real heading (see title_tag).
        renders_one :title
        # Muted copy under the title.
        renders_one :description

        # The title's heading level - a real heading element, so set it
        # to fit the page outline.
        option :title_tag, :symbol, default: :h3
        # The media slot's treatment; :icon gives the rounded muted icon tile.
        option :media_variant, :symbol, default: :default

        validates :title_tag, inclusion: { in: %i[h1 h2 h3 h4 h5 h6] }
        validates :media_variant, inclusion: { in: %i[default icon] }

        part "empty", "The empty-state root - the centered header and content stack"
        part "empty-header", "Wrapper around media/title/description - renders when at " \
                             "least one of those slots is set"
        part "empty-icon", "The media slot's box - media_variant: :icon gives the rounded " \
                           "muted icon tile",
             states: {
               "data-variant" => { condition: "always - the resolved media_variant",
                                   values: %w[default icon] }
             }
        part "empty-title", "The title as a real heading (title_tag, h3 by default)"
        part "empty-description", "Muted copy under the title"
        part "empty-content", "The actions that fix the emptiness - the content block " \
                              "renders here"

        # Whether the header wrapper renders (any of media/title/description set).
        # @api private
        def header?
          media? || title? || description?
        end

        # The media box's classes for the resolved media_variant.
        # @api private
        def media_classes
          variant = media_variant == :icon ? :media_icon : :media_default
          "#{css(:media)} #{css(variant)}"
        end

        # The empty-state root's attributes.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "empty" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
