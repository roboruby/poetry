# frozen_string_literal: true

module Poetry
  module Ui
    # The popper-consumer kit: what every trigger-anchored popup surface
    # (Popover, HoverCard, Tooltip) re-typed - the placement vocabulary,
    # the calibrated placement options, the popper content-var contract,
    # and the trigger/content id pair. The use_stimulus DECLARATIONS stay
    # per-family on purpose: they are the contract's projection surface
    # and each family's value set genuinely differs.
    module PopperConsumer
      extend ActiveSupport::Concern
      include FamilyIdentity

      SIDES = %i[top right bottom left].freeze
      ALIGNS = %i[start center end].freeze

      class_methods do
        # The five placement options plus their vocabulary validations -
        # each family passes its own source-calibrated defaults.
        def popper_placement_options(side:, side_offset:, align: :center, align_offset: 0)
          option :side, :symbol, default: side
          option :align, :symbol, default: align
          option :side_offset, :integer, default: side_offset
          option :align_offset, :integer, default: align_offset
          option :avoid_collisions, :boolean, default: true
          validates :side, inclusion: { in: SIDES }
          validates :align, inclusion: { in: ALIGNS }
        end
      end

      # The content part's popper var contract - noun names the family's
      # surface in the prose ("panel", "bubble").
      def self.content_vars(noun = "panel")
        {
          "--transform-origin" => "the anchor-facing origin popper writes for scale-in animation",
          "--available-width" => "viewport space left for the #{noun} (popper, post-flip)",
          "--available-height" => "viewport space left for the #{noun} (popper, post-flip)",
          "--anchor-width" => "the anchor's measured width (popper)",
          "--anchor-height" => "the anchor's measured height (popper)"
        }
      end

      def trigger_id
        "#{instance_id}-trigger"
      end

      # The controller resolves content by the id pair ("-trigger" ->
      # "-content"), portal-safe - no Stimulus target.
      def content_id
        "#{instance_id}-content"
      end
    end
  end
end
