# frozen_string_literal: true

module Poetry
  module Ui
    # File/image upload chips.
    module Attachment
      # A file or image chip showing an upload's name, metadata, and
      # lifecycle state. The server owns the state: render state:
      # (idle/uploading/processing/error/done) and update it by
      # re-rendering or a Turbo Stream replace - the component ships no
      # upload JavaScript of its own.
      #
      # In-flight and error states carry a translated screen-reader
      # status announcement; the visual lifecycle is pure CSS.
      #
      # @example A finished upload
      #   render Poetry::Ui::Attachment::Component.new do |attachment|
      #     attachment.with_title { "quarterly-report.pdf" }
      #     attachment.with_description { "1.2 MB" }
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the state axis (the server-owned upload lifecycle).
        STATES = %i[idle uploading processing error done].freeze
        # The closed vocabulary for the size axis.
        SIZES = %i[default sm xs].freeze
        # The closed vocabulary for the orientation axis.
        ORIENTATIONS = %i[horizontal vertical].freeze
        # The closed vocabulary for the with_media variant.
        MEDIA_VARIANTS = %i[icon image].freeze
        # States that render the screen-reader status announcement.
        ANNOUNCED_STATES = %i[uploading processing error].freeze

        # Projected into the registry, llms.txt, and the agent surface.
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

        renders_one :media,
                    doc: "Leading visual: :icon (default) boxes an icon tile, :image wraps the caller's <img>.",
                    renders: lambda { |variant: :icon, &block|
                      unless MEDIA_VARIANTS.include?(variant)
                        raise ArgumentError,
                              "media variant must be :icon or :image"
                      end

                      content_tag(:div, "data-slot" => "attachment-media", "data-variant" => variant,
                                        class: css(:media, class: (if variant == :image
                                                                     "cn-attachment-media-variant-image"
                                                                   end)), &block)
                    }
        renders_one :title, doc: "The file name line. User content - never mark it html_safe."
        renders_one :description, doc: "Muted metadata under the title (size, type); in the error state, the " \
                                       "failure explanation."
        renders_many :actions,
                     doc: "Trailing icon actions - each renders a Button (ghost, icon-xs defaults) and requires " \
                          "label:.",
                     renders: lambda { |label:, **options, &block|
                       # Caller data: augments the slot marker instead of replacing it
                       # at the kwargs splat.
                       data = { slot: "attachment-action" }.merge(options.delete(:data) || {})
                       Button::Component.new(variant: options.delete(:variant) || :ghost,
                                             size: options.delete(:size) || :"icon-xs",
                                             label: label, data: data, **options, &block)
                     }
        renders_one :trigger,
                    doc: "Makes the whole chip the control - a stretched button (or anchor via tag: :a, href:) " \
                         "layered under the actions. Don't also wrap the chip in a link.",
                    renders: lambda { |tag: :button, href: nil, **options, &block|
                      attrs = Poetry::Core::HTML::Attributes.merged(
                        { class: css(:trigger), "data-slot" => "attachment-trigger" }, options
                      )
                      attrs[:type] = "button" if tag == :button
                      attrs[:href] = href if tag == :a
                      content_tag(tag, attrs, &block)
                    }

        style :size, default: :default, required: true, variants: SIZES, doc: "The chip density axis."
        style :orientation, default: :horizontal, required: true, variants: ORIENTATIONS,
                            doc: "Row (:horizontal) or stacked thumbnail-card (:vertical) layout."

        option :state, :symbol, default: :done,
                                doc: "The upload lifecycle state; flip it by re-render or Turbo Stream replace, " \
                                     "never in JS."

        validates :state, inclusion: { in: STATES }

        part "attachment", "The chip root - the server-owned upload lifecycle rides here " \
                           "(flip data-upload-state by re-render / Turbo Stream replace)",
             states: {
               "data-upload-state" => { condition: "always - the resolved state",
                                        values: STATES.map(&:to_s) },
               "data-size" => { condition: "always - the resolved size",
                                values: SIZES.map(&:to_s) },
               "data-orientation" => { condition: "always - the resolved orientation",
                                       values: ORIENTATIONS.map(&:to_s) }
             }
        part "attachment-media", "The media slot's box - the icon tile or the caller's <img>",
             states: {
               "data-variant" => { condition: "always - the media variant",
                                   values: MEDIA_VARIANTS.map(&:to_s) }
             }
        part "attachment-content", "Text column wrapping title/description - renders when " \
                                   "either slot is set"
        part "attachment-title", "The file name line (title slot; user content, never html_safe)"
        part "attachment-description", "Muted metadata / failure copy under the title"
        part "attachment-actions", "Row of with_action poetry Buttons"
        part "attachment-trigger", "The whole-chip control (with_trigger: a button or tag: :a " \
                                   "anchor) - wraps the picker/download affordance"
        part "attachment-status", "sr-only role=status announcement for the in-flight and " \
                                  "error states (uploading/processing/error)"

        # Whether the current state renders the screen-reader status announcement.
        # @api private
        def announced?
          ANNOUNCED_STATES.include?(state)
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "attachment", "data-upload-state" => state,
              "data-size" => size, "data-orientation" => orientation
            }.merge(component_data_attributes)
          )
        end

        private :announced?, :root_attributes
      end
    end
  end
end
