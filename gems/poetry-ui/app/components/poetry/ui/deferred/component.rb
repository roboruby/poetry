# frozen_string_literal: true

require "digest"

module Poetry
  module Ui
    module Deferred
      # N13 W5: a deferred region. Turbo owns the loading physics
      # (loading: :lazy fetches when the frame becomes VISIBLE - so a
      # deferred Tabs panel or HoverCard body loads on first reveal with
      # no extra wiring; :eager fetches right after paint). poetry owns
      # the states: a Skeleton placeholder (the component block overrides
      # it) and a visible, retryable error card via poetry--core--deferred
      # - Turbo alone leaves failure as silent blankness.
      #
      # Styleless on purpose: the frame and placeholder are structural
      # wrappers; Skeleton and Button bring the themed surfaces, and the
      # error card rides static template utilities (scanned into the
      # safelist like every committed template class).
      class Component < Poetry::Core::Component
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

        AGENT_RULES = [
          "Use poetry_deferred(src:) for expensive regions - never a spinner div + a hand-rolled fetch.",
          "loading: :lazy (the default) fetches on visibility: a deferred region inside a hidden " \
          "Tabs panel (with_tab defer:) or HoverCard (defer:) loads on first reveal for free.",
          "The block is the placeholder (a Skeleton renders when absent); failure shows a retryable " \
          "error card automatically - never hand-wire loading or error states around it."
        ].freeze

        # required: the hand raise in before_render carries the message;
        # the flag carries the fact to the registry (: the floating
        # crash - a required option the static tier could not see).
        option :src, :string, required: true
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

        def before_render
          raise ArgumentError, "poetry_deferred requires src:" if src.blank?
        end

        # No src in the markup ON PURPOSE: the URL rides the controller
        # value and connect() arms it, so a fast response can never beat
        # the controllers module graph to the frame (the Turbo 8
        # frame-missing default would promote that failure to a full-page
        # visit - caught live on the docs site).
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
