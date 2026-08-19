# frozen_string_literal: true

require "action_view/record_identifier"
require "digest/md5"
require "random/formatter"

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
      # The thread-local sequence generator (the OPT-IN mode, default
      # off). Same page -> same seed -> identical id sequence across
      # renders, which is what byte-stable content pages need for Turbo
      # morph and body-hash ETags. The hazards that keep it opt-in are
      # documented where the mode is: same-path turbo-frames restart the
      # sequence and collide deterministically, and reordered same-type
      # collections get POSITIONAL false identity (state on the wrong
      # record) - keyed identity (key:) is the general answer; this mode
      # exists for static/content pages a host judges safe.
      SEQUENCE_KEY = :poetry_stable_id_sequence

      module_function

      # Deterministic ids inside the block: with_seed is honored
      # REGARDLESS of stable_id_mode (an explicit call is explicit
      # intent - it is also the test API). The around_action is what the
      # mode gates.
      def with_seed(seed)
        previous = Thread.current[SEQUENCE_KEY]
        Thread.current[SEQUENCE_KEY] = sequence_for(seed)
        yield
      ensure
        Thread.current[SEQUENCE_KEY] = previous
      end

      # The next deterministic token, or nil when no sequence is armed
      # (callers fall through to the random rung).
      def next_sequence_token
        Thread.current[SEQUENCE_KEY]&.hex(8)
      end

      # Random::Formatter over a digest-seeded PRNG (the a sibling gem recipe):
      # hex(8) matches the random fallback's shape exactly, so the mode
      # is invisible in the DOM.
      def sequence_for(seed)
        Random.new(Digest::MD5.hexdigest(seed.to_s).to_i(16))
      end

      # The opt-in request seeding (engine-installed on every controller,
      # inert unless stable_id_mode == :sequence): seeds the thread-local
      # sequence from the configured lambda (default: request.path -
      # matching Turbo's own page-refresh pathname test) around each
      # action, always restoring after.
      module Controller
        extend ActiveSupport::Concern

        included do
          around_action :poetry_stable_id_sequence
        end

        private

        def poetry_stable_id_sequence(&)
          config = Poetry::Core::Config.current
          return yield unless config.stable_id_mode == :sequence

          Poetry::Core::StableId.with_seed(config.stable_id_seed.call(request), &)
        end
      end

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
