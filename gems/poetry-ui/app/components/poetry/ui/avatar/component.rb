# frozen_string_literal: true

module Poetry
  module Ui
    # Person images with initials fallbacks.
    module Avatar
      # A person's image over an always-rendered initials fallback. The
      # image layers absolutely above the fallback with an empty alt, so a
      # failed load paints nothing and the initials show through - zero
      # JS, no layout shift. The accessible name lives on the root
      # (role=img + aria-label via label:), never on the layered img.
      #
      # @example Image with initials fallback
      #   render Poetry::Ui::Avatar::Component.new(src: user.avatar_url, label: "Ada Lovelace") { "AL" }
      class Component < Poetry::Core::Component
        requires_content "the initials fallback"

        # The closed vocabulary for the size axis.
        SIZES = %i[default sm lg].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "label: (the person's name) is REQUIRED - it is the avatar's accessible name (role=img).",
          "The content block is the fallback (initials) and is also required - it is what shows " \
          "while the image loads or when it fails.",
          "The badge slot is decorative (a presence dot); put the status meaning in label:, " \
          "not in the badge.",
          "Stack avatars with poetry_avatar_group; the overflow count is poetry_avatar_group_count."
        ].freeze

        slot_doc :badge, "Decorative presence dot, bottom-right; keep the status meaning in label:."
        renders_one :badge

        option :src, :string, doc: "The image URL; without it only the initials fallback shows."
        option :label, :string, required: true,
                                doc: "The person's name - the avatar's accessible name (blank raises). The required " \
                                     "flag also carries the fact to the registry so static checks see it."
        option :size, :symbol, default: :default, doc: "The diameter axis."

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

        # Enforces label: and the initials content block.
        # @api private
        def before_render
          raise ArgumentError, "Avatar requires label: (the person's name - its accessible name)" if label.blank?

          ensure_content!
        end

        # @api private
        def call
          content_tag(:span, root_attributes.to_attributes) do
            safe_join([fallback, image, badge_part].compact)
          end
        end

        # @api private
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

        private :root_attributes
      end
    end
  end
end
