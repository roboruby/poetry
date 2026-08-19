# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # The identity core (StableId plan S0): key-token derivation and the
    # poetry_instance_id ladder. The contract under test: explicit id
    # wins; key: derives dom_id-first (so a host's to_key override - the
    # obfuscation lever - propagates); everything else falls back random,
    # because unkeyed components must over-replace under morph, never
    # falsely retain.
    class StableIdTest < Minitest::Test
      class Message
        include ActiveModel::Model

        attr_accessor :id

        def persisted? = id.present?
        def to_key = persisted? ? [id] : nil
      end

      class SluggedMessage < Message
        attr_accessor :slug

        # The railsdesigner dom-id-without-primary-id pattern: the HOST
        # opts into obfuscation at the model layer, and dom_id (thus
        # poetry) inherits it.
        def to_key = [slug]
      end

      class LadderComponent < Poetry::Core::Component
        def call
          "".html_safe
        end
      end

      def test_records_derive_dom_id
        assert_equal "poetry_core_stable_id_test_message_42",
                     StableId.key_token(Message.new(id: 42))
      end

      def test_to_key_override_propagates_the_obfuscation_lever
        token = StableId.key_token(SluggedMessage.new(slug: "a1b2c3"))

        assert_equal "poetry_core_stable_id_test_slugged_message_a1b2c3", token
        refute_includes token, "42"
      end

      def test_new_records_derive_the_new_prefix
        assert_equal "new_poetry_core_stable_id_test_message",
                     StableId.key_token(Message.new)
      end

      def test_literals_parameterize
        assert_equal "faq-section", StableId.key_token("FAQ Section")
        assert_equal "billing", StableId.key_token(:billing)
        assert_equal "42", StableId.key_token(42)
      end

      def test_unusable_keys_yield_nil_for_the_random_fallback
        assert_nil StableId.key_token(nil)
        assert_nil StableId.key_token("!!!")
      end

      def test_ladder_explicit_id_beats_key
        component = LadderComponent.new(id: "settings", key: "ignored")

        assert_equal "settings", component.poetry_instance_id("poetry-tabs")
      end

      def test_ladder_key_derives_a_namespaced_stable_token
        a = LadderComponent.new(key: Message.new(id: 7))
        b = LadderComponent.new(key: Message.new(id: 7))

        assert_equal a.poetry_instance_id("poetry-tabs"), b.poetry_instance_id("poetry-tabs")
        assert_equal "poetry-tabs-poetry_core_stable_id_test_message_7",
                     a.poetry_instance_id("poetry-tabs")
      end

      def test_ladder_falls_back_to_random_hex8
        a = LadderComponent.new.poetry_instance_id("poetry-tabs")
        b = LadderComponent.new.poetry_instance_id("poetry-tabs")

        assert_match(/\Apoetry-tabs-\h{16}\z/, a)
        refute_equal a, b, "unkeyed instances must not share ids"
      end

      def test_key_never_renders_as_an_html_attribute
        component = LadderComponent.new(key: "faq", class: "w-full")

        refute component.html_attributes.key?("key")
        assert_equal "faq", component.stable_key
      end

      # --- S3: the opt-in sequence mode ---

      def test_with_seed_is_deterministic_and_isolated
        a = StableId.with_seed("/products") { Array.new(3) { StableId.next_sequence_token } }
        b = StableId.with_seed("/products") { Array.new(3) { StableId.next_sequence_token } }
        c = StableId.with_seed("/pricing") { Array.new(3) { StableId.next_sequence_token } }

        assert_equal a, b, "same seed must replay the same sequence"
        refute_equal a, c, "different seeds must not share sequences"
        assert_nil StableId.next_sequence_token, "no sequence armed outside the block"
      end

      def test_with_seed_nests_and_restores_on_raise
        outer = StableId.with_seed("/outer") do
          first = StableId.next_sequence_token
          StableId.with_seed("/inner") { StableId.next_sequence_token }
          [first, StableId.next_sequence_token]
        end

        expected = StableId.with_seed("/outer") { Array.new(2) { StableId.next_sequence_token } }

        assert_equal expected, outer, "the inner seed must not disturb the outer sequence"

        assert_raises(RuntimeError) { StableId.with_seed("/x") { raise "boom" } }
        assert_nil StableId.next_sequence_token, "ensure must clear the sequence after a raise"
      end

      def test_the_golden_vector_is_pinned
        # THE UPGRADE CONTRACT: these literals are what seed "/products"
        # allocates. Changing the allocator (digest, PRNG, token width)
        # re-identifies every component on every sequence-mode page across
        # a gem upgrade - if this test fails, that is what you are
        # shipping. Bump the literals only with a changelog entry.
        vector = StableId.with_seed("/products") { Array.new(3) { StableId.next_sequence_token } }

        assert_equal %w[75ebad7272c22911 e3241b3f8dbd9be4 5d28a721bac8fc34], vector
      end

      def test_ladder_sequence_sits_between_key_and_random
        ids = StableId.with_seed("/page") do
          [LadderComponent.new.poetry_instance_id("poetry-tabs"),
           LadderComponent.new(key: "faq").poetry_instance_id("poetry-tabs"),
           LadderComponent.new(id: "settings").poetry_instance_id("poetry-tabs")]
        end
        replay = StableId.with_seed("/page") { LadderComponent.new.poetry_instance_id("poetry-tabs") }

        assert_equal 28, ids[0].length # "poetry-tabs-" + hex(8)
        assert_equal replay, ids[0], "unkeyed draws replay under the same seed"
        assert_equal "poetry-tabs-faq", ids[1], "key: beats the sequence"
        assert_equal "settings", ids[2], "explicit id beats everything"
      end

      def test_sequence_survives_the_live_style_thread_local_copy
        # ActionController::Live copies Thread.current locals into its
        # response thread (actionpack live.rb) - this mirrors that exact
        # mechanism and proves an armed sequence keeps drawing there.
        child_tokens = StableId.with_seed("/live") do
          StableId.next_sequence_token # consume one on the request thread
          t1 = Thread.current
          locals = t1.keys.map { |key| [key, t1[key]] }
          Thread.new do
            locals.each { |k, v| Thread.current[k] = v }
            Array.new(2) { StableId.next_sequence_token }
          end.value
        end

        expected = StableId.with_seed("/live") do
          StableId.next_sequence_token
          Array.new(2) { StableId.next_sequence_token }
        end

        assert_equal expected, child_tokens
      end
    end
  end
end
