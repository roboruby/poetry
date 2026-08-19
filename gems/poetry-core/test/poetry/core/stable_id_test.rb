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
    end
  end
end
