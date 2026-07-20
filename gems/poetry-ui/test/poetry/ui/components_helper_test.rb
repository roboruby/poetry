# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The poetry_* helpers ARE the agent-facing surface llms.txt teaches
    # ("render components with their poetry_<name> helpers") - the
    # fresh-app proof (2026-07-01) caught 8 of 10 missing.
    class ComponentsHelperTest < ActionDispatch::IntegrationTest
      def render_erb(erb)
        ApplicationController.renderer.render(inline: erb, layout: false)
      end

      def test_every_registered_component_has_its_helper
        # The drift gate: a new component without its poetry_<name> helper
        # fails here, not in a consumer's app.
        Poetry::Core::Registry.new(source_root: Poetry::Ui.root).components.each do |component|
          helper = "poetry_#{component.name.deconstantize.demodulize.underscore}"

          assert_includes ComponentsHelper.instance_methods, helper.to_sym,
                          "missing #{helper} - every registered component ships its helper"
        end
      end

      def test_helpers_render_with_content_blocks
        html = render_erb(%(<%= poetry_badge(variant: :secondary) { "beta" } %>))

        assert_includes html, 'data-component="badge"'
        assert_includes html, ">beta</span>"
      end

      def test_slot_blocks_receive_the_component
        html = render_erb(<<~ERB)
          <%= poetry_dialog do |dialog| %>
            <% dialog.with_trigger { "Open" } %>
            <% dialog.with_title { "Settings" } %>
            Body
          <% end %>
        ERB

        assert_includes html, "<dialog"
        assert_includes html, ">Settings</h2>"
      end

      def test_tooltip_provider_renders_the_config_carrying_scope
        html = render_erb(<<~ERB)
          <%= poetry_tooltip_provider(delay_duration: 700) do %>
            row
          <% end %>
        ERB

        # A config div, NOT a controller - the tooltip controller reads the
        # closest provider ancestor and keys the warm registry by it.
        assert_includes html, 'data-slot="tooltip-provider"'
        assert_includes html, 'data-delay-duration="700"'
        assert_includes html, 'data-skip-delay-duration="300"'
        assert_includes html, 'data-disable-hoverable-content="false"'
        refute_includes html, "data-controller"
      end

      def test_void_component_helpers_render
        html = render_erb(%(<%= poetry_input(type: "email", name: "q") %>))

        assert_includes html, 'data-component="input"'
        assert_includes html, 'type="email"'
      end

      def test_wrapper_helpers_never_yield_anything_to_their_blocks
        # The yieldless-block check rule rests on this roster
        # invariant: no poetry_* wrapper helper passes an argument to its
        # block (a declared block param is always nil at render - the W2r
        # app_shell crash). A future yielding wrapper must put the yield
        # behind a component, or extend the rule - this tripwire forces
        # that decision consciously.
        source = Poetry::Ui.root.join("app/helpers/poetry/ui/components_helper.rb").read

        refute_match(/\byield\b/, source, "wrapper helpers must not yield")
        assert_empty source.scan(/capture\((?!&)[^)]*\)/), "capture must take only the block, never arguments"
        refute_match(/block\.call\(.+\)/, source, "blocks must not be called with arguments")
      end

      def test_color_scheme_script_bootstraps_before_paint_and_wires_the_api
        html = render_erb(%(<%= poetry_color_scheme_script %>))

        assert_match(/\A<script/, html)
        assert_includes html, %(localStorage.getItem(KEY)), "reads the stored preference"
        assert_includes html, %("poetry-color-scheme"), "the documented storage key"
        assert_includes html, %(prefers-color-scheme: dark), "falls back to the OS preference"
        assert_includes html, 'classList.toggle("dark"', "applies the mode as the .dark class"
        assert_includes html, %(window.Poetry.colorScheme), "exposes the switch API"
        assert_includes html, %(poetry:color-scheme), "announces changes for redraw listeners"
      end
    end
  end
end
