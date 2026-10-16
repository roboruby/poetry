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
      # overlay:. Every selected file is an Attachment chip under the zone.
      #
      # The native input is always the form value. With direct_upload: true
      # Active Storage's direct uploads run at submit, Rails' own flow, and
      # the chips show their progress; with upload: :immediate each file
      # uploads as it lands, with progress, cancel, retry and remove, and
      # the form posts the signed ids the uploads leave as hidden inputs.
      #
      # @example Drag-and-drop upload surface
      #   render Poetry::Ui::FileInput::Component.new(
      #     variant: :dropzone, name: "attachments[]", multiple: true,
      #     accept: "application/pdf,image/*", max_size: 10.megabytes, max_files: 5,
      #     direct_upload: true, upload: :immediate, preview: true,
      #     hint: "PDF or PNG, up to 10 MB"
      #   )
      class Component < Poetry::Core::Component
        # The rejection codes the file_drop behavior reports, by the
        # translation key of their message.
        REJECTION_CODES = {
          type: "file-invalid-type", large: "file-too-large", small: "file-too-small",
          count: "too-many-files", invalid: "file-invalid"
        }.freeze
        # The upload messages the file-input controller shows, by translation key.
        UPLOAD_MESSAGES = %i[unavailable failed busy].freeze
        # The closed vocabulary for camera: (the native capture attribute's values).
        CAMERAS = %i[user environment].freeze
        # The closed vocabulary for upload: (when direct uploads run).
        UPLOAD_MODES = %i[on_submit immediate].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "File selection is a FileInput: variant: :input for compact forms, :dropzone when " \
          "dragging is expected (uploads as the page's point) - never a hand-rolled drop div.",
          "The native input is the form value: set name: (multiple: true wants a name ending " \
          "in [] for Rails params); direct_upload: true runs Active Storage's direct uploads at submit, " \
          "upload: :immediate as files land.",
          "The dropzone's chips, rejections and clear button are controller-rendered - " \
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
              value :upload, from: :upload_mode
              value :name
              value :url, from: :upload_url
              value :preview
              value :messages, from: :upload_messages
              action :files, on: event(:file_drop, :files)
            end
          end
          on :control do
            controller(:file_drop) { target :input }
            controller(:file_input) { target :input }
          end
          on :items do
            controller(:file_input) { target :items }
          end
          on :template do
            controller(:file_input) { target :template }
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
          on :item_remove do
            controller(:file_input) { action :remove, on: :click }
          end
          on :item_retry do
            controller(:file_input) { action :retry, on: :click }
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
        option :direct_upload, :boolean, default: false,
                                         doc: "Uploads go straight to the storage service through Active Storage's " \
                                              "direct uploads endpoint, as Rails' file_field direct_upload: true."
        option :direct_upload_url, :string, doc: "A direct uploads endpoint other than Rails' own (an authenticated " \
                                                 "subclass's route); implies direct_upload: true."
        option :upload, :symbol, default: :on_submit,
                                 doc: "When direct uploads run: :on_submit, Rails' own flow at form submit, or " \
                                      ":immediate, each file as it lands with progress, cancel, retry and remove, " \
                                      "the form posting signed ids."
        option :preview, :boolean, default: false, doc: "Image files show a thumbnail in their chip, from an object " \
                                                        "URL released when the chip goes."
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
        validates :upload, inclusion: { in: UPLOAD_MODES }

        part "file-input", "The dropzone root - the drop target, wrapping the zone, the chips, the " \
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
                                   "dropzone, THE form value in both variants",
             states: {
               "data-direct-upload-url" => { condition: "direct_upload: true or direct_upload_url: with the " \
                                                        "default upload: :on_submit - Rails' own submit-time " \
                                                        "upload handler reads it" }
             }
        part "file-input-prompt", "The zone's instruction line (prompt: overrides the default)"
        part "file-input-hint", "Muted constraints copy under the prompt (hint: - formats, size)"
        part "file-input-items", "The chips' container the controller fills - one Attachment per selected " \
                                 "file, cloned from the template (chips are controller-built, not server parts)"
        part "file-input-item-template", "The <template> holding one Attachment chip the controller clones per " \
                                         "file: media, title, description, progress, retry and remove"
        part "file-input-errors", "The rejections <ul> (role=alert) the controller fills - one line per file " \
                                  "the accept, size or count checks refused; hidden when empty"
        part "file-input-overlay", "The fixed full-window drop surface (overlay: true) - decorative, shown " \
                                   "while data-drag-global is on the root"
        part "file-input-clear", "The clear affordance - hidden until populated; never re-opens " \
                                 "the picker"

        # Enforces visible prompt text on the dropzone variant and a direct
        # uploads endpoint behind upload: :immediate.
        # @api private
        def before_render
          # The dropzone announces itself through the label text; the input
          # variant is named externally (Field/Label) like any Input.
          if variant == :dropzone && prompt_text.blank?
            raise ArgumentError, "FileInput dropzone requires visible prompt text"
          end
          return unless upload == :immediate && upload_url.nil?

          raise ArgumentError, "FileInput upload: :immediate needs direct_upload: true or direct_upload_url:"
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

        # The upload messages, translated, as the JSON the file-input
        # controller reads.
        # @api private
        def upload_messages
          UPLOAD_MESSAGES.to_h { |key| [key, t("poetry.file_input.upload.#{key}")] }.to_json
        end

        # The direct uploads endpoint: the explicit one, else Rails' own
        # when direct_upload: is on, else nil (no direct uploads).
        # @api private
        def upload_url
          return @upload_url if defined?(@upload_url)

          @upload_url = if direct_upload_url.present?
                          direct_upload_url
                        elsif direct_upload
                          rails_direct_uploads_url
                        end
        end

        # Rails' direct uploads route, or a clear error when the host has
        # not drawn it.
        # @api private
        def rails_direct_uploads_url
          unless helpers.respond_to?(:rails_direct_uploads_url)
            raise ArgumentError, "FileInput direct_upload: true needs Active Storage's direct uploads route " \
                                 "(config.active_storage.draw_direct_upload_route) - or pass direct_upload_url:"
          end

          helpers.rails_direct_uploads_url
        end

        # The controller's upload mode: none without an endpoint, else the
        # upload: option.
        # @api private
        def upload_mode
          upload_url ? upload.to_s : "none"
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
                "aria-describedby" => described_by, "data-direct-upload-url" => upload_url }.compact,
            **html_attributes.to_attributes.transform_keys(&:to_sym)
          )
        end

        # The hidden native input's attributes (dropzone variant). Rails'
        # own submit-time uploads read data-direct-upload-url; in immediate
        # mode the controller owns the uploads, so the input carries none.
        # @api private
        def control_attributes
          attrs = {
            "type" => "file", "class" => "sr-only", "data-slot" => "file-input-control",
            "name" => name, "id" => id, "accept" => accept, "capture" => camera,
            "aria-describedby" => described_by,
            "data-direct-upload-url" => (upload_url if upload_mode == "on_submit")
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

        # The chips' container's attributes.
        # @api private
        def items_attributes
          { "data-slot" => "file-input-items", "class" => css(:items) }.merge(stimulus_attributes_for(:items))
        end

        # The chip template's attributes.
        # @api private
        def template_attributes
          { "data-slot" => "file-input-item-template" }.merge(stimulus_attributes_for(:template))
        end

        # The chip the controller clones per file: an Attachment with every
        # seat the uploads fill, the actions wired to this controller.
        # @api private
        def item_template_component
          Attachment::Component.new(state: :done, size: :sm)
        end

        # A chip action's data: the wiring's action string plus the role the
        # controller reads to show or hide it.
        # @api private
        def item_action_data(element, role)
          { action: stimulus_attributes_for(element)["data-action"], upload_action: role }
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

        private :prompt_text, :rejection_messages, :upload_messages, :upload_url, :rails_direct_uploads_url
        private :upload_mode, :input_variant_component, :control_attributes, :dropzone_attributes
        private :items_attributes, :template_attributes, :item_template_component, :item_action_data
        private :errors_attributes, :clear_attributes
      end
    end
  end
end
