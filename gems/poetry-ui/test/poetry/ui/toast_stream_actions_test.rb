# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # turbo_stream.poetry_toast - the canonical server-side toast.
    # poetry-ui does not depend on turbo-rails, so the module is exercised
    # against a minimal builder double exposing the same #append seam the
    # real Turbo::Streams::TagBuilder provides (the engine mixes the
    # module in through the :turbo_streams_tag_builder load hook).
    class ToastStreamActionsTest < ViewComponent::TestCase
      class BuilderDouble
        include Poetry::Ui::ToastStreamActions

        attr_reader :target, :appended

        def append(target, content)
          @target = target
          @appended = content
          [target, content]
        end
      end

      def test_appends_a_toast_component_into_the_permanent_region
        builder = BuilderDouble.new
        builder.poetry_toast(title: "Changes saved", description: "Profile updated.", variant: :success)

        assert_equal "poetry-toaster", builder.target
        assert_instance_of Toast::Component, builder.appended

        html = render_inline(builder.appended).to_html

        assert_includes html, 'data-variant="success"'
        assert_includes html, "Changes saved"
        assert_includes html, "Profile updated."
      end

      def test_the_block_configures_slots_before_the_append
        builder = BuilderDouble.new
        builder.poetry_toast(title: "Message deleted") { |toast| toast.with_action { "Undo" } }

        html = render_inline(builder.appended).to_html

        # The action slot flowed through - and made the toast persistent
        # (the missable-undo guard).
        assert_includes html, 'data-slot="toast-action"'
        assert_includes html, 'data-poetry--core--toast-duration-value="0"'
      end

      def test_the_target_is_overridable
        builder = BuilderDouble.new
        builder.poetry_toast(title: "Saved", target: "sidebar-toaster")

        assert_equal "sidebar-toaster", builder.target
      end

      def test_the_engine_registers_the_turbo_load_hook
        # turbo-rails is not a dependency: the hook must simply be wired
        # (it no-ops until a host loads turbo). Rails keeps load hooks in
        # ActiveSupport::LazyLoadHooks' registry.
        hooks = ActiveSupport.instance_variable_get(:@load_hooks)

        assert hooks.key?(:turbo_streams_tag_builder),
               "the poetry_ui.turbo_stream_actions initializer must register the load hook"
      end
    end
  end
end
