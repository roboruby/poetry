# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # The content-return guard: a block that returns a scalar while
    # writing nothing captures as nothing (poetry_badge { count } renders
    # an empty badge). A requires_content component raises in development
    # and test and logs in production; every other component logs.
    class ContentGuardTest < ViewComponent::TestCase
      module Probe
        class Component < Poetry::Core::Component
          requires_content "the probe body"

          def before_render = ensure_content!

          def call
            content_tag(:span, content, class: "probe")
          end
        end
      end

      module Lenient
        class Component < Poetry::Core::Component
          def call
            content_tag(:span, content, class: "lenient")
          end
        end
      end

      module Composed
        class Component < Poetry::Core::Component
          requires_content "the body"

          renders_one :part

          def call
            content_tag(:span, safe_join([part, content].compact), class: "composed")
          end
        end
      end

      def test_a_scalar_return_on_a_requires_content_component_raises_in_test
        error = assert_raises(ArgumentError) { render_inline(Probe::Component.new) { 42 } }

        assert_equal "probe content block returned 42 (Integer), which captures as nothing - " \
                     "return a String (call to_s on it) or write it with <%= %>", error.message
        assert_raises(ArgumentError) { render_inline(Probe::Component.new) { :draft } }
        assert_raises(ArgumentError) { render_inline(Probe::Component.new) { true } }
      end

      def test_a_string_return_renders_escaped
        html = render_inline(Probe::Component.new) { "<b>3</b>" }.to_html

        assert_includes html, "&lt;b&gt;3&lt;/b&gt;"
        assert_includes render_inline(Probe::Component.new) { "42".html_safe }.to_html, ">42<"
      end

      def test_nil_and_collection_returns_are_not_scalars
        assert_includes render_inline(Probe::Component.new) { nil }.to_html, %(<span class="probe"></span>)
        assert_includes render_inline(Probe::Component.new) { [] }.to_html, %(<span class="probe"></span>)
        assert_includes render_inline(Probe::Component.new) { {} }.to_html, %(<span class="probe"></span>)
      end

      def test_a_composition_block_ending_on_a_slot_setter_is_not_a_scalar
        html = render_inline(Composed::Component.new) { |composed| composed.with_part { "slotted" } }.to_html

        assert_includes html, "slotted", "with_part returns the slot - composition, not a lost value"
        chained = render_inline(Composed::Component.new) { |composed| composed.with_part { "s" } && composed }

        assert_includes chained.to_html, "s", "a block returning the component is composition too"
      end

      def test_a_block_that_wrote_to_the_buffer_may_return_anything
        html = render_in_view_context do
          render(Probe::Component.new) do
            concat("written")
            42
          end
        end

        assert_includes html.to_s, %(<span class="probe">written</span>)
      end

      def test_a_component_without_the_declaration_logs_and_renders_empty
        log = StringIO.new
        original = Rails.logger
        Rails.logger = Logger.new(log)
        html = render_inline(Lenient::Component.new) { 42 }.to_html

        assert_includes html, %(<span class="lenient"></span>)
        assert_match(/poetry: lenient content block returned 42 \(Integer\)/, log.string)
      ensure
        Rails.logger = original
      end

      def test_production_logs_and_renders_empty
        log = StringIO.new
        original_logger = Rails.logger
        original_env = Rails.env
        Rails.logger = Logger.new(log)
        view = vc_test_view_context # built under the test environment, before the flip
        Rails.env = "production"
        html = Probe::Component.new.render_in(view) { 42 }

        assert_includes html, %(<span class="probe"></span>)
        assert_match(/poetry: probe content block returned 42 \(Integer\)/, log.string)
      ensure
        Rails.logger = original_logger
        Rails.env = original_env
      end

      def test_a_missing_block_still_raises_the_declaration
        error = assert_raises(ArgumentError) { render_inline(Probe::Component.new) }

        assert_equal "Probe requires a content block (the probe body)", error.message
      end
    end
  end
end
