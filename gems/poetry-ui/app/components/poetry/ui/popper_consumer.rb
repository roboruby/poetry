# frozen_string_literal: true

module Poetry
  module Ui
    # Gives a trigger-anchored popup component (Popover, HoverCard,
    # Tooltip) the shared positioning surface: the placement vocabulary,
    # the popper_placement_options macro, the content part's CSS-var
    # contract, and the trigger/content id pair. Stimulus declarations
    # stay per-family: each family's value set genuinely differs.
    module PopperConsumer
      extend ActiveSupport::Concern
      include FamilyIdentity

      # The closed vocabulary for the side placement axis.
      SIDES = %i[top right bottom left].freeze
      # The closed vocabulary for the align placement axis.
      ALIGNS = %i[start center end].freeze

      class_methods do
        # Declares the five placement options (side, align, side_offset,
        # align_offset, avoid_collisions) plus their vocabulary
        # validations on the including component - each family passes its
        # own defaults.
        def popper_placement_options(side:, side_offset:, align: :center, align_offset: 0)
          option :side, :symbol, default: side, doc: "Which side of the anchor the panel opens on."
          option :align, :symbol, default: align, doc: "Panel alignment along the chosen side."
          option :side_offset, :integer, default: side_offset,
                                         doc: "Gap in pixels between the anchor and the panel."
          option :align_offset, :integer, default: align_offset,
                                          doc: "Shift in pixels along the alignment axis."
          option :avoid_collisions, :boolean, default: true,
                                              doc: "Flips and shifts the panel to stay inside the viewport."
          validates :side, inclusion: { in: SIDES }
          validates :align, inclusion: { in: ALIGNS }
        end
      end

      # The CSS custom properties the positioning engine writes onto the
      # content part - inlined into a family's part declaration as its
      # vars:. noun names the family's surface in the prose ("panel",
      # "bubble").
      def self.content_vars(noun = "panel")
        {
          "--transform-origin" => "the anchor-facing origin popper writes for scale-in animation",
          "--available-width" => "viewport space left for the #{noun} (popper, post-flip)",
          "--available-height" => "viewport space left for the #{noun} (popper, post-flip)",
          "--anchor-width" => "the anchor's measured width (popper)",
          "--anchor-height" => "the anchor's measured height (popper)"
        }
      end

      # The trigger element's server-stable id.
      # @api private
      def trigger_id
        "#{instance_id}-trigger"
      end

      # The content element's server-stable id. The controller resolves
      # content by the id pair ("-trigger" -> "-content"), portal-safe -
      # no Stimulus target.
      # @api private
      def content_id
        "#{instance_id}-content"
      end

      private :trigger_id, :content_id
    end
  end
end
