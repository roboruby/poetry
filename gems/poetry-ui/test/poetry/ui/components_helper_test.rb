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

      def test_void_component_helpers_render
        html = render_erb(%(<%= poetry_input(type: "email", name: "q") %>))

        assert_includes html, 'data-component="input"'
        assert_includes html, 'type="email"'
      end
    end
  end
end
