# frozen_string_literal: true

module Poetry
  module Ui
    module Attachment
      # File/image chip for the AI-chat set (Attachment).
      # poetry ships the ATTRIBUTE CONTRACT: the server renders data-upload-state
      # (idle|uploading|processing|error|done) and flips it by re-render /
      # Turbo Stream replace - upload orchestration is explicitly the
      # host's. In-flight and error states carry an sr-only role=status
      # announcement (i18n'd); the visual lifecycle is pure CSS.
      class Component < Poetry::Core::Component
        STATES = %i[idle uploading processing error done].freeze
        SIZES = %i[default sm xs].freeze
        ORIENTATIONS = %i[horizontal vertical].freeze
        MEDIA_VARIANTS = %i[icon image].freeze
        ANNOUNCED_STATES = %i[uploading processing error].freeze

        AGENT_RULES = [
          "State is server-owned: render data-upload-state and flip it by Turbo Stream replace - " \
          "never toggle it in JS.",
          "with_media(variant: :image) wraps the caller's <img>; file names and URLs are " \
          "user content - never render them html_safe.",
          "Actions are with_action(...) poetry Buttons (ghost/icon-xs defaults) - each needs label: (icon-only).",
          "with_trigger makes the whole chip the control (a stretched overlay UNDER the " \
          "actions) - don't also wrap the chip in a link.",
          "error state needs a with_description explaining the failure - the tint alone is not the message."
        ].freeze

        style :size, default: :default, required: true, variants: SIZES
        style :orientation, default: :horizontal, required: true, variants: ORIENTATIONS

        option :state, :symbol, default: :done

        validates :state, inclusion: { in: STATES }

        renders_one :media, lambda { |variant: :icon, &block|
          raise ArgumentError, "media variant must be :icon or :image" unless MEDIA_VARIANTS.include?(variant)

          content_tag(:div, class: css(:media), "data-slot" => "attachment-media",
                            "data-variant" => variant, &block)
        }
        renders_one :title
        renders_one :description
        renders_many :actions, lambda { |label:, **options, &block|
          Button::Component.new(variant: options.delete(:variant) || :ghost,
                                size: options.delete(:size) || :"icon-xs",
                                label: label, data: { slot: "attachment-action" }, **options, &block)
        }
        renders_one :trigger, lambda { |tag: :button, href: nil, **options, &block|
          attrs = { class: css(:trigger), "data-slot" => "attachment-trigger" }.merge(options)
          attrs[:type] = "button" if tag == :button
          attrs[:href] = href if tag == :a
          content_tag(tag, attrs, &block)
        }

        def announced?
          ANNOUNCED_STATES.include?(state)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "attachment", "data-upload-state" => state,
              "data-size" => size, "data-orientation" => orientation
            }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
