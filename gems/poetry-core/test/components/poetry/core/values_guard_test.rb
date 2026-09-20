# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # The runtime values tier: the declared vocabulary is enforced at
    # construction for every component - raise in development and test
    # with the allowed values and a did-you-mean, log in production.
    class ValuesGuardTest < ViewComponent::TestCase
      module Probe
        class Component < Poetry::Core::Component
          style :tone, default: :sky, variants: %i[sky rose amber]
          style :muted, variants: :boolean
          style :shape, variants: %i[round square]
          option :label, :string, required: true

          def call
            content_tag(:span, label, class: css)
          end
        end
      end

      def test_an_off_list_variant_raises_with_the_allowed_values_and_a_suggestion
        error = assert_raises(ArgumentError) { Probe::Component.new(label: "x", tone: :rosy) }

        assert_equal "probe tone: :rosy is not one of :sky, :rose, :amber (did you mean :rose?)", error.message
      end

      def test_a_missing_required_option_raises
        error = assert_raises(ArgumentError) { Probe::Component.new }

        assert_match(/probe requires label:/, error.message)
      end

      def test_omitted_styles_are_not_off_list_values
        component = Probe::Component.new(label: "x")

        assert_nil component.shape
        assert_nil component.muted
        assert_predicate component, :valid?
      end

      # A boolean style casts its value (ActiveModel), so an off-list value
      # never reaches the inclusion check; the guard has nothing to say.
      def test_a_boolean_style_casts_instead_of_raising
        assert Probe::Component.new(label: "x", muted: "true").muted
        refute Probe::Component.new(label: "x", muted: "0").muted
      end

      # Outside local environments the guard logs and renders (the same
      # posture as the passthrough guard, whose predicate it shares).
      module Lenient
        class Component < Probe::Component
          private

          def strict_passthrough?
            false
          end
        end
      end

      module Closed
        class Component < Poetry::Core::Component
          style :tone, default: :sky, variants: %i[sky rose]

          def call = "c"
        end
      end

      module Opened
        class Component < Closed::Component
          # Redeclared without variants: open, whatever the parent listed.
          style :tone, default: :any

          def call = "o"
        end
      end

      def test_a_subclass_that_redeclares_a_style_without_variants_is_open
        assert_equal :whatever, Opened::Component.new(tone: :whatever).tone
        assert_nil Opened::Component.runtime_vocabulary.fetch(:tone)[:variants]
        assert_raises(ArgumentError) { Closed::Component.new(tone: :whatever) }
      end

      module Dictionaryless
        class Component < Poetry::Core::Component
          def call = "d"
        end
      end

      def test_a_missing_style_class_is_logged_once_per_class
        log = StringIO.new
        original = Rails.logger
        Rails.logger = Logger.new(log)
        Rails.logger.level = Logger::DEBUG
        3.times { Dictionaryless::Component.style_class }

        assert_equal 1, log.string.scan("Style class not found").size
      ensure
        Rails.logger = original
      end

      def test_production_logs_and_renders
        log = StringIO.new
        original = Rails.logger
        Rails.logger = Logger.new(log)
        html = render_inline(Lenient::Component.new(label: "x", tone: :rosy)).to_html

        assert_includes html, "x"
        assert_match(/poetry: lenient tone: :rosy is not one of :sky, :rose, :amber/, log.string)
      ensure
        Rails.logger = original
      end
    end
  end
end
