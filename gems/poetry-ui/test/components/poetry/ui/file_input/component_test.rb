# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module FileInput
      class ComponentTest < ViewComponent::TestCase
        DIRECT = "/rails/active_storage/direct_uploads"

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
          assert_nil input["data-direct-upload-url"], "no direct uploads unless asked"
        end

        def test_without_direct_uploads_the_controller_runs_no_upload_mode
          root = render_inline(Component.new(variant: :dropzone, name: "f")).at_css("[data-slot=file-input]")

          assert_equal "none", root["data-poetry--core--file-input-upload-value"]
          assert_equal "f", root["data-poetry--core--file-input-name-value"]
          assert_nil root["data-poetry--core--file-input-url-value"]
          assert_equal "false", root["data-poetry--core--file-input-preview-value"]
          messages = JSON.parse(root["data-poetry--core--file-input-messages-value"])

          assert_equal %w[busy failed unavailable], messages.keys.sort
        end

        def test_direct_upload_url_puts_rails_own_flow_on_the_input
          doc = render_inline(Component.new(variant: :dropzone, name: "docs[]", multiple: true,
                                            direct_upload_url: DIRECT))

          assert_equal DIRECT, doc.at_css("input[type=file]")["data-direct-upload-url"],
                       "Rails' submit handler reads it"
          root = doc.at_css("[data-slot=file-input]")

          assert_equal "on_submit", root["data-poetry--core--file-input-upload-value"]
          assert_equal DIRECT, root["data-poetry--core--file-input-url-value"]
        end

        def test_immediate_uploads_keep_the_endpoint_off_the_input_and_on_the_controller
          doc = render_inline(Component.new(variant: :dropzone, name: "photos[]", multiple: true,
                                            direct_upload_url: DIRECT,
                                            upload: :immediate, preview: true))

          assert_nil doc.at_css("input[type=file]")["data-direct-upload-url"], "Rails must not upload these at submit"
          root = doc.at_css("[data-slot=file-input]")

          assert_equal "immediate", root["data-poetry--core--file-input-upload-value"]
          assert_equal DIRECT, root["data-poetry--core--file-input-url-value"]
          assert_equal "true", root["data-poetry--core--file-input-preview-value"]
        end

        def test_immediate_without_an_endpoint_raises
          error = assert_raises(ArgumentError) do
            render_inline(Component.new(variant: :dropzone, name: "f", upload: :immediate))
          end

          assert_match(/upload: :immediate needs direct_upload: true or direct_upload_url:/, error.message)
        end

        def test_direct_upload_true_without_the_route_names_the_fix
          error = assert_raises(ArgumentError) do
            render_inline(Component.new(variant: :dropzone, name: "f", direct_upload: true))
          end

          assert_match(/draw_direct_upload_route/, error.message)
        end

        def test_the_chip_template_carries_every_seat_the_uploads_fill
          doc = render_inline(Component.new(variant: :dropzone, name: "f"))
          template = doc.at_css("template[data-slot=file-input-item-template]")

          assert_equal "template", template["data-poetry--core--file-input-target"]
          chip = Nokogiri::HTML5.fragment(template.inner_html).at_css("[data-slot=attachment]")

          assert chip, "one Attachment chip inside the template"
          assert_equal "done", chip["data-upload-state"]
          assert_equal "sm", chip["data-size"]
          %w[attachment-media attachment-title attachment-description attachment-progress].each do |slot|
            assert chip.at_css("[data-slot=#{slot}]"), "the #{slot} seat"
          end
          progress = chip.at_css("[data-slot=attachment-progress]")

          assert_equal "progressbar", progress["role"]
          assert progress["hidden"], "the bar shows while uploading"
          retry_button = chip.at_css("[data-upload-action=retry]")
          remove_button = chip.at_css("[data-upload-action=remove]")

          assert_equal "click->poetry--core--file-input#retry", retry_button["data-action"]
          assert retry_button["hidden"], "retry shows after a failure"
          assert_equal "click->poetry--core--file-input#remove", remove_button["data-action"]
          assert_equal "Remove", remove_button["aria-label"]
          assert doc.at_css("[data-slot=file-input-items][data-poetry--core--file-input-target=items]")
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

        def test_the_input_variant_renders_the_input_component_with_camera_and_direct_upload
          doc = render_inline(Component.new(name: "photo", accept: "image/*", camera: :user, direct_upload_url: DIRECT,
                                            "aria-label": "Photo"))
          input = doc.at_css("input[type=file]")

          assert_equal "user", input["capture"]
          assert_equal "Photo", input["aria-label"]
          assert_equal DIRECT, input["data-direct-upload-url"]
          assert_nil doc.at_css("[data-controller]"), "the plain control carries no JavaScript"
        end

        def test_camera_and_upload_are_closed_vocabularies
          assert_raises(ArgumentError) { Component.new(name: "f", camera: :selfie) }
          assert_raises(ArgumentError) { Component.new(name: "f", upload: :whenever) }
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
