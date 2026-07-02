# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Stimulus
      # Manifest validation on the Builder: the Ruby<->JS action-contract
      # seam, guarded at render time (2026-07-01 review-sweep adoption).
      class ManifestValidationTest < Minitest::Test
        def dialog_builder(attrs = HTML::Attributes.new)
          Builder.new(%i[poetry core dialog], attrs)
        end

        def test_the_manifest_self_loads_from_the_committed_json
          assert Manifest.catalog.key?("poetry--core--dialog")
          assert_includes Manifest.catalog.dig("poetry--core--dialog", "methods"), "backdropClose"
        end

        def test_unknown_poetry_controller_raises_with_the_known_list
          error = assert_raises(Manifest::UnknownController) do
            Builder.new(%i[poetry core dropdown], HTML::Attributes.new)
          end

          assert_includes error.message, "poetry--core--dialog", "the fix is in the message (agent-teachable)"
        end

        def test_host_app_controllers_are_not_poetrys_to_validate
          builder = Builder.new("dropdown", HTML::Attributes.new)

          assert_equal "dropdown#anything", builder.action(:anything)
        end

        def test_snake_case_camelizes_to_the_js_method_name
          assert_equal "click->poetry--core--dialog#backdropClose",
                       dialog_builder.action(:backdrop_close, on: :click)
        end

        def test_unknown_action_method_raises_at_build_time
          error = assert_raises(Manifest::UnknownName) { dialog_builder.action(:dismiss) }

          assert_includes error.message, "backdropClose, close"
        end

        def test_unknown_value_raises
          assert_raises(Manifest::UnknownName) { dialog_builder.with_value(:closable, true) }
        end

        def test_known_value_emits_the_attribute
          attrs = HTML::Attributes.new
          dialog_builder(attrs).with_value(:dismissible, false)

          assert_equal "false", attrs.to_attributes["data-poetry--core--dialog-dismissible-value"]
        end

        def test_with_target_validates_and_emits
          attrs = HTML::Attributes.new
          dialog_builder(attrs).with_target(:dialog)

          assert_equal "dialog", attrs.to_attributes["data-poetry--core--dialog-target"]
          assert_raises(Manifest::UnknownName) { dialog_builder.with_target(:panel) }
        end

        def test_global_event_target_formats_as_event_at_target
          # The ported code emitted "keydown@keydown->..." - locked fixed.
          assert_equal "keydown@window->poetry--core--dialog#close",
                       dialog_builder.action(:close, on: :keydown, at: :window)
        end
      end
    end
  end
end
