# frozen_string_literal: true

require "action_view/record_identifier"

module Poetry
  module Core
    # Semantic identity for component DOM ids (the StableId plan): a
    # caller-supplied key: becomes a component-namespaced, render-stable
    # token, so Turbo morph pairs the same logical component across
    # renders and cached fragments stay composable.
    #
    # Derivation is deliberately dom_id-first, never slug-sniffing:
    # records go through ActionView::RecordIdentifier.dom_id, which
    # respects a host's `def to_key = [slug]` override - the one lever
    # that keeps key:, turbo_frame_tag, and Turbo Stream broadcast
    # targets emitting the SAME identity everywhere (turbo-rails calls
    # RecordIdentifier internally). Plain values parameterize. Slugs
    # read directly would be mutable and recyclable (a freed slug
    # claimed by another record re-creates false identity), and poetry
    # preferring them while the host's own dom_id stays pk-based would
    # split one app into two id vocabularies.
    module StableId
      module_function

      # The stable token for a key:, or nil when no usable token exists
      # (callers fall back to random - fail toward correctness).
      # Records (anything dom_id can address) -> dom_id; everything else
      # -> to_s.parameterize. New records derive "new_<model>" - two of
      # those on one page collide, so repeated new-record forms need
      # explicit keys (documented).
      def key_token(key)
        return nil if key.nil?

        if key.respond_to?(:to_model) || key.respond_to?(:model_name)
          ActionView::RecordIdentifier.dom_id(key)
        else
          key.to_s.parameterize.presence
        end
      end
    end
  end
end
