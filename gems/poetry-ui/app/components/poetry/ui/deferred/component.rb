# frozen_string_literal: true

require "digest"

module Poetry
  module Ui
    # Deferred family: lazy-loaded regions with loading and error states.
    module Deferred
      # A deferred region: a Turbo Frame that fetches its content when it
      # becomes VISIBLE (loading: :lazy, the default - so a deferred Tabs
      # panel or HoverCard body loads on first reveal with no extra
      # wiring) or right after paint (:eager). The block is the loading
      # placeholder (a Skeleton renders when absent), and a failed fetch
      # shows a visible, retryable error card instead of silent
      # blankness.
      #
      # @example
      #   render Poetry::Ui::Deferred::Component.new(src: "/dashboard/activity")
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Use poetry_deferred(src:) for expensive regions - never a spinner div + a hand-rolled fetch.",
          "loading: :lazy (the default) fetches on visibility: a deferred region inside a hidden " \
          "Tabs panel (with_tab defer:) or HoverCard (defer:) loads on first reveal for free.",
          "The block is the placeholder (a Skeleton renders when absent); failure shows a retryable " \
          "error card automatically - never hand-wire loading or error states around it."
        ].freeze

        use_stimulus do
          # src rides the controller value, NOT the frame markup: connect()
          # arms it, so a fast response can never beat the controllers
          # module graph to the frame.
          on :root do
            controller :deferred do
              register
              value :src
            end
          end
          # Template-consumed elements (previously hand-written strings).
          on :placeholder do
            controller(:deferred) { target :placeholder }
          end
          on :error_template do
            controller(:deferred) { target :error }
          end
          on :retry do
            controller(:deferred) { action :retry, on: :click }
          end
        end

        # The URL to fetch - required; rendering without it raises.
        option :src, :string, required: true
        # :lazy fetches when the frame becomes visible; :eager fetches
        # right after paint.
        option :loading, :symbol, default: :lazy

        part "deferred", "The <turbo-frame> root - src is armed at connect(); failure is " \
                         "a state reflected here, never silent blankness",
             states: {
               "data-error" => "a frame fetch failed (error response, missing frame, or " \
                               "network error) - the controller stamps the error card; " \
                               "retry clears it"
             }
        part "deferred-error", "The retryable error card, stamped into the frame from the " \
                               "slotted <template> on failure"

        # Enforces the required src.
        # @api private
        def before_render
          raise ArgumentError, "poetry_deferred requires src:" if src.blank?
        end

        # No src in the markup ON PURPOSE: the URL rides the controller
        # value and connect() arms it, so a fast response can never beat
        # the controllers module graph to the frame (Turbo 8's
        # frame-missing default would promote that race to a full-page
        # visit).
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "id" => "poetry-deferred-#{Digest::MD5.hexdigest(src.to_s).first(8)}",
              "loading" => loading, "data-slot" => "deferred"
            }.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end
      end
    end
  end
end
