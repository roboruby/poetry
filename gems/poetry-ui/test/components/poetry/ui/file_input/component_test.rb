# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module FileInput
      class ComponentTest < ViewComponent::TestCase
        def test_the_dropzone_wires_the_file_drop_behavior_beside_its_own_controller
          doc = render_inline(Component.new(variant: :dropzone, name: "files[]", multiple: true, accept: "image/*,.pdf",
                                            max_size: 1024, max_files: 3, paste: true))
          root = doc.at_css("[data-slot=file-input]")

          assert_equal "poetry--core--file-drop poetry--core--file-input", root["data-controller"]
          assert_equal "image/*,.pdf", root["data-poetry--core--file-drop-accept-value"]
          assert_equal "true", root["data-poetry--core--file-drop-multiple-value"]
          assert_equal "1024", root["data-poetry--core--file-drop-max-size-value"]
          assert_equal "3", root["data-poetry--core--file-drop-max-files-value"]
          assert_equal "true", root["data-poetry--core--file-drop-paste-value"]
          assert_nil root["data-poetry--core--file-drop-min-size-value"], "an unset limit declares nothing"
          assert_includes root["data-action"], "poetry:file-drop:files->poetry--core--file-input#files"
          messages = JSON.parse(root["data-poetry--core--file-drop-messages-value"])

          assert_equal Component::REJECTION_CODES.values.sort, messages.keys.sort
          assert_equal "{name} is larger than {size}", messages["file-too-large"]
        end

        def test_the_native_input_is_both_controllers_target_and_carries_the_native_attributes
          doc = render_inline(Component.new(variant: :dropzone, name: "shots[]", multiple: true, accept: "image/*",
                                            camera: :environment, directory: true))
          input = doc.at_css("input[type=file]")

          assert_equal "input", input["data-poetry--core--file-drop-target"]
          assert_equal "input", input["data-poetry--core--file-input-target"]
          assert_equal "environment", input["capture"]
          assert input["webkitdirectory"], "directory: true asks the picker for folders"
          assert input["multiple"]
          assert_equal "sr-only", input["class"]
        end

        def test_the_rejections_list_and_the_clear_button_start_hidden
          doc = render_inline(Component.new(variant: :dropzone, name: "f"))
          errors = doc.at_css("[data-slot=file-input-errors]")

          assert_equal "alert", errors["role"]
          assert errors["hidden"]
          assert_equal "errors", errors["data-poetry--core--file-input-target"]
          assert doc.at_css("[data-slot=file-input-clear]")["hidden"]
          assert_nil doc.at_css("[data-slot=file-input-overlay]"), "no overlay unless asked"
        end

        def test_overlay_renders_the_full_window_surface_and_declares_the_value
          doc = render_inline(Component.new(variant: :dropzone, name: "f", overlay: true))

          assert_equal "true", doc.at_css("[data-slot=file-input]")["data-poetry--core--file-drop-overlay-value"]
          overlay = doc.at_css("[data-slot=file-input-overlay]")

          assert_equal "true", overlay["aria-hidden"]
          assert_includes overlay.text, "Drop files to add them"
        end

        def test_the_input_variant_renders_the_input_component_with_camera
          doc = render_inline(Component.new(name: "photo", accept: "image/*", camera: :user, "aria-label": "Photo"))
          input = doc.at_css("input[type=file]")

          assert_equal "user", input["capture"]
          assert_equal "Photo", input["aria-label"]
          assert_nil doc.at_css("[data-controller]"), "the plain control carries no JavaScript"
        end

        def test_camera_is_a_closed_vocabulary
          assert_raises(ArgumentError) do
            render_inline(Component.new(name: "f", camera: :selfie))
          end
        end

        def test_the_behavior_rule_leads_the_agent_rules
          rules = Component.agent_rules

          assert_match(/advisory/, rules.first)
          assert_includes rules, Component::AGENT_RULES.first
        end
      end
    end
  end
end
