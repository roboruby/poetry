# frozen_string_literal: true

module Poetry
  module Ui
    module Avatar
      # The Avatar - a person's image over an initials fallback, with the
      # server-native fallback strategy: the fallback ALWAYS renders and the
      # image sits absolutely above it with alt="" - a failed load paints
      # nothing, so the initials show through. Zero JS, no layout shift (vs
      # Base UI's client-side load-state swap). The accessible name lives on
      # the root (role=img + aria-label), never on the layered img.
      class Component < Poetry::Core::Component
        SIZES = %i[default sm lg].freeze

        AGENT_RULES = [
          "label: (the person's name) is REQUIRED - it is the avatar's accessible name (role=img).",
          "The content block is the fallback (initials) and is also required - it is what shows " \
          "while the image loads or when it fails.",
          "The badge slot is decorative (a presence dot); put the status meaning in label:, " \
          "not in the badge.",
          "Stack avatars with poetry_avatar_group; the overflow count is poetry_avatar_group_count."
        ].freeze

        option :src, :string
        # required: the hand raise in before_render carries the message;
        # the flag carries the fact to the registry (: the floating
        # crash - a required option the static tier could not see).
        option :label, :string, required: true
        option :size, :symbol, default: :default

        validates :size, inclusion: { in: SIZES }

        part "avatar", "Root span (role=img carrying the accessible name) - fallback, image, " \
                       "and badge layer inside it",
             states: {
               "data-size" => { condition: "always - the resolved size", values: SIZES.map(&:to_s) }
             }
        part "avatar-fallback", "The initials layer (the content block) - always in the DOM, " \
                                "showing until the image covers it"
        part "avatar-image", "The <img> layered absolutely over the fallback - only when src: " \
                             "is given; a failed load paints nothing"
        part "avatar-badge", "The decorative presence dot (the badge slot), bottom-right"

        renders_one :badge

        requires_content "the initials fallback"

        def before_render
          raise ArgumentError, "Avatar requires label: (the person's name - its accessible name)" if label.blank?

          ensure_content!
        end

        def call
          content_tag(:span, root_attributes.to_attributes) do
            safe_join([fallback, image, badge_part].compact)
          end
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "avatar", "data-size" => size,
              "role" => "img", "aria-label" => label
            }.merge(component_data_attributes)
          )
        end

        private

        def fallback
          content_tag(:span, content, "data-slot" => "avatar-fallback", "aria-hidden" => "true",
                                      class: css(:fallback))
        end

        def image
          return if src.blank?

          # alt="" on purpose: the root carries the name, and an empty alt
          # keeps a FAILED load from painting a broken-image glyph over the
          # initials - the layered-fallback contract.
          tag.img(src: src, alt: "", "data-slot": "avatar-image", class: css(:image))
        end

        def badge_part
          return unless badge?

          content_tag(:span, badge, "data-slot" => "avatar-badge", "aria-hidden" => "true", class: css(:badge))
        end
      end
    end
  end
end
