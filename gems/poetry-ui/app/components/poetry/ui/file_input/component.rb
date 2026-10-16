# frozen_string_literal: true

module Poetry
  module Ui
    # The FileInput family - file selection as a plain control or a dropzone.
    module FileInput
      # The FileInput - file
      # selection in two shapes. variant: :input is the plain styled native
      # control (the Input component with type=file - zero JS, the browser
      # shows the selection). variant: :dropzone is the drag-and-drop
      # surface: a <label> wrapping a visually-hidden native input - so
      # click-to-browse and keyboard access are the PLATFORM's - with the
      # file_drop behavior adding what HTML cannot: drop, paste, folders, the
      # accept, size and count checks, and the whole page as the target with
      # overlay:. The native input is always the form value; ActiveStorage
      # direct upload rides it untouched (data: { direct_upload_url: ... }
      # passes straight through).
      #
      # @example Drag-and-drop upload surface
      #   render Poetry::Ui::FileInput::Component.new(
      #     variant: :dropzone, name: "attachments[]", multiple: true,
      #     accept: "application/pdf,image/*", max_size: 10.megabytes, max_files: 5,
      #     hint: "PDF or PNG, up to 10 MB"
      #   )
      class Component < Poetry::Core::Component
        # The rejection codes the file_drop behavior reports, by the
        # translation key of their message.
        REJECTION_CODES = {
          type: "file-invalid-type", large: "file-too-large", small: "file-too-small",
          count: "too-many-files", invalid: "file-invalid"
        }.freeze
        # The closed vocabulary for camera: (the native capture attribute's values).
        CAMERAS = %i[user environment].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "File selection is a FileInput: variant: :input for compact forms, :dropzone when " \
          "dragging is expected (uploads as the page's point) - never a hand-rolled drop div.",
          "The native input is the form value: set name: (multiple: true wants a name ending " \
          "in [] for Rails params); ActiveStorage direct upload attaches to it as usual.",
          "The dropzone's selected-file list, rejections and clear button are controller-rendered - " \
          "compose prompt:/hint: copy instead of adding your own list markup.",
          "Limits are options, never prose alone: accept:, max_size: and max_files: reject the file " \
          "at intake; the hint: tells people the same limits in words.",
          "In a Field, prefer form.file_input (the builder wires id/label/errors); the bare " \
          "component suits standalone dropzones."
        ].freeze

        use_stimulus do
          on :root do
            behavior :file_drop, accept: :option, multiple: :option, max_files: :option, max_size: :option,
                                 min_size: :option, paste: :option, overlay: :option, directory: :option,
                                 messages: { from: :rejection_messages }
            controller :file_input do
              register
              value :multiple
              action :files, on: event(:file_drop, :files)
            end
          end
          on :control do
            controller(:file_drop) { target :input }
            controller(:file_input) { target :input }
          end
          on :list do
            controller(:file_input) { target :list }
          end
          on :errors do
            controller(:file_input) { target :errors }
          end
          on :clear do
            controller :file_input do
              target :clear
              action :clear, on: :click
            end
          end
        end

        style :variant, default: :input, variants: %i[input dropzone],
                        doc: ":input is the compact native control; :dropzone the drag-and-drop surface."

        option :name, :string,
               doc: "The native input's name - the submitted param (multiple: true wants a name ending in [] for " \
                    "Rails params)."
        option :id, :string, doc: "The native input's id (Field/FormBuilder wire it to the label)."
        option :multiple, :boolean, default: false,
                                    doc: "Allows selecting several files; forwarded to the native input."
        option :accept, :string, doc: "The native accept filter (e.g. \"image/*,.pdf\"); the dropzone rejects " \
                                      "a file outside it at intake."
        option :max_size, :integer, doc: "The largest file the dropzone takes, in bytes (10.megabytes)."
        option :min_size, :integer, doc: "The smallest file the dropzone takes, in bytes."
        option :max_files, :integer, doc: "The most files the dropzone holds (multiple: true); the surplus is " \
                                          "rejected file by file."
        option :paste, :boolean, default: false, doc: "Files pasted over the dropzone land in it (a chat composer, " \
                                                      "a screenshot)."
        option :overlay, :boolean, default: false, doc: "The whole page is the drop target: a fixed overlay shows " \
                                                        "while files are dragged over the window."
        option :directory, :boolean, default: false, doc: "Dropped folders are walked for their files, and the " \
                                                          "picker selects folders."
        option :camera, :symbol, doc: "Opens a camera on mobile, as the native capture attribute: :user (front) or " \
                                      ":environment (back); needs an image, audio or video accept:."
        option :disabled, :boolean, default: false, doc: "Disables the native input and dims the dropzone."
        option :invalid, :boolean, default: false,
                                   doc: "Marks the control aria-invalid (set by Field/FormBuilder from model errors)."
        option :described_by, :string, doc: "Ids for the native input's aria-describedby (Field wires this)."
        option :prompt, :string, doc: "The dropzone's instruction line - overrides the translated default."
        option :hint, :string, doc: "Muted constraints copy under the prompt (formats, size limits)."

        validates :camera, inclusion: { in: CAMERAS }, allow_nil: true

        part "file-input", "The dropzone root - the drop target, wrapping the zone, the selection list, the " \
                           "rejections and clear",
             states: {
               "data-variant" => { condition: "always on the dropzone root (the input variant " \
                                              "renders the Input component instead)",
                                   values: %w[dropzone] },
               "data-dragging" => { condition: "a file drag is over the zone (controller-written, " \
                                               "enter/leave counted)" },
               "data-drag-reject" => { condition: "the drag carries only files the accept filter or the count " \
                                                  "would reject (controller-written, best effort mid-drag)" },
               "data-drag-global" => { condition: "overlay: true and files are dragged anywhere over the " \
                                                  "window (controller-written)" },
               "data-populated" => { condition: "the native input holds at least one file " \
                                                "(controller-written)" }
             }
        part "file-input-dropzone", "The <label> drop surface - dashed, platform click-to-browse; " \
                                    "its text is the control's accessible name"
        part "file-input-control", "The native <input type=file> - visually hidden in the " \
                                   "dropzone, THE form value in both variants"
        part "file-input-prompt", "The zone's instruction line (prompt: overrides the default)"
        part "file-input-hint", "Muted constraints copy under the prompt (hint: - formats, size)"
        part "file-input-list", "The selected-file <ul> the controller fills (name + size per " \
                                "item; items are controller-built, not server parts)"
        part "file-input-errors", "The rejections <ul> (role=alert) the controller fills - one line per file " \
                                  "the accept, size or count checks refused; hidden when empty"
        part "file-input-overlay", "The fixed full-window drop surface (overlay: true) - decorative, shown " \
                                   "while data-drag-global is on the root"
        part "file-input-clear", "The clear affordance - hidden until populated; never re-opens " \
                                 "the picker"

        # Enforces visible prompt text on the dropzone variant.
        # @api private
        def before_render
          # The dropzone announces itself through the label text; the input
          # variant is named externally (Field/Label) like any Input.
          return unless variant == :dropzone && prompt_text.blank?

          raise ArgumentError, "FileInput dropzone requires visible prompt text"
        end

        # The resolved instruction line (prompt: or the translated default).
        # @api private
        def prompt_text
          prompt.presence || t("poetry.file_input.prompt")
        end

        # The rejection messages by code, translated, as the JSON the
        # file-drop controller reads; the {name}, {size}, {count} and
        # {reason} tokens are the controller's to fill.
        # @api private
        def rejection_messages
          REJECTION_CODES.to_h { |key, code| [code, t("poetry.file_input.rejected.#{key}")] }.to_json
        end

        # The input variant renders the Input component AS the whole
        # surface, so the FileInput's own extra attributes (aria-label,
        # class, data-*) must forward onto it - dropping them would strand
        # the accessible name.
        # @api private
        def input_variant_component
          Input::Component.new(
            type: "file", name: name, disabled: disabled, invalid: invalid,
            **{ "id" => id, "accept" => accept, "multiple" => multiple || nil, "capture" => camera,
                "aria-describedby" => described_by }.compact,
            **html_attributes.to_attributes.transform_keys(&:to_sym)
          )
        end

        # The hidden native input's attributes (dropzone variant).
        # @api private
        def control_attributes
          attrs = {
            "type" => "file", "class" => "sr-only", "data-slot" => "file-input-control",
            "name" => name, "id" => id, "accept" => accept, "capture" => camera,
            "aria-describedby" => described_by
          }.compact
          attrs["multiple"] = true if multiple
          attrs["webkitdirectory"] = true if directory
          attrs["disabled"] = true if disabled
          attrs["aria-invalid"] = "true" if invalid
          attrs.merge(stimulus_attributes_for(:control))
        end

        # The dropzone root's attributes.
        def root_attributes
          super({ "data-variant" => variant })
        end

        # The <label> drop surface's attributes.
        # @api private
        def dropzone_attributes
          {
            "data-slot" => "file-input-dropzone",
            "class" => "#{css(:dropzone)}#{" #{css(:dropzone_disabled)}" if disabled}"
          }
        end

        # The controller-filled selection list's attributes.
        # @api private
        def list_attributes
          { "data-slot" => "file-input-list", "class" => css(:list) }
            .merge(stimulus_attributes_for(:list))
        end

        # The controller-filled rejections list's attributes (role=alert,
        # hidden until a file is refused).
        # @api private
        def errors_attributes
          { "data-slot" => "file-input-errors", "role" => "alert", "hidden" => true, "class" => css(:errors) }
            .merge(stimulus_attributes_for(:errors))
        end

        # The clear button's attributes (hidden until files are selected).
        # @api private
        def clear_attributes
          { "type" => "button", "data-slot" => "file-input-clear", "hidden" => true,
            "class" => css(:clear) }
            .merge(stimulus_attributes_for(:clear))
        end

        private :prompt_text, :rejection_messages, :input_variant_component, :control_attributes
        private :dropzone_attributes, :list_attributes, :errors_attributes, :clear_attributes
      end
    end
  end
end
