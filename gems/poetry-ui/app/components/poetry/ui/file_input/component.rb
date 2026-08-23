# frozen_string_literal: true

module Poetry
  module Ui
    module FileInput
      # The FileInput - file
      # selection in two shapes. variant: :input is the plain styled native
      # control (the Input component with type=file - zero JS, the browser
      # shows the selection). variant: :dropzone is the drag-and-drop
      # surface: a <label> wrapping a visually-hidden native input - so
      # click-to-browse and keyboard access are the PLATFORM's - with the
      # poetry--core--file-input controller adding only what HTML cannot
      # (drop, the selection list, clear). The native input is always the
      # form value; ActiveStorage direct upload rides it untouched
      # (data: { direct_upload_url: ... } passes straight through).
      # Styling is utility-only (the Separator/Spinner rule).
      #
      # @example Drag-and-drop upload surface
      #   render Poetry::Ui::FileInput::Component.new(
      #     variant: :dropzone, name: "attachments[]", multiple: true,
      #     hint: "PDF or PNG, up to 10 MB"
      #   )
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "File selection is a FileInput: variant: :input for compact forms, :dropzone when " \
          "dragging is expected (uploads as the page's point) - never a hand-rolled drop div.",
          "The native input is the form value: set name: (multiple: true wants a name ending " \
          "in [] for Rails params); ActiveStorage direct upload attaches to it as usual.",
          "The dropzone's selected-file list and clear button are controller-rendered - compose " \
          "prompt:/hint: copy instead of adding your own list markup.",
          "In a Field, prefer form.file_input (the builder wires id/label/errors); the bare " \
          "component suits standalone dropzones."
        ].freeze

        use_stimulus do
          on :root do
            controller :file_input do
              register
              value :multiple
            end
          end
          on :dropzone do
            controller :file_input do
              action :dragenter, on: :dragenter
              action :dragover, on: :dragover
              action :dragleave, on: :dragleave
              action :drop, on: :drop
            end
          end
          on :control do
            controller :file_input do
              target :input
              action :changed, on: :change
            end
          end
          on :list do
            controller(:file_input) { target :list }
          end
          on :clear do
            controller :file_input do
              target :clear
              action :clear, on: :click
            end
          end
        end

        style :variant, default: :input, variants: %i[input dropzone]

        option :name, :string
        option :id, :string
        option :multiple, :boolean, default: false
        option :accept, :string
        option :disabled, :boolean, default: false
        option :invalid, :boolean, default: false
        option :described_by, :string
        option :prompt, :string
        option :hint, :string

        part "file-input", "The dropzone root - wraps the zone, the selection list, and clear",
             states: {
               "data-variant" => { condition: "always on the dropzone root (the input variant " \
                                              "renders the Input component instead)",
                                   values: %w[dropzone] },
               "data-dragging" => { condition: "a file drag is over the zone (controller-written, " \
                                               "enter/leave counted)" },
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
        part "file-input-clear", "The clear affordance - hidden until populated; never re-opens " \
                                 "the picker"

        def before_render
          # The dropzone announces itself through the label text; the input
          # variant is named externally (Field/Label) like any Input.
          return unless variant == :dropzone && prompt_text.blank?

          raise ArgumentError, "FileInput dropzone requires visible prompt text"
        end

        def prompt_text
          prompt.presence || t("poetry.file_input.prompt")
        end

        # The input variant renders the Input component AS the whole
        # surface, so the FileInput's own extra attributes (aria-label,
        # class, data-*) forward onto it - dropping them stranded the
        # accessible name (axe caught it).
        def input_variant_component
          Input::Component.new(
            type: "file", name: name, disabled: disabled, invalid: invalid,
            **{ "id" => id, "accept" => accept, "multiple" => multiple || nil,
                "aria-describedby" => described_by }.compact,
            **html_attributes.to_attributes.transform_keys(&:to_sym)
          )
        end

        def control_attributes
          attrs = {
            "type" => "file", "class" => "sr-only", "data-slot" => "file-input-control",
            "name" => name, "id" => id, "accept" => accept,
            "aria-describedby" => described_by
          }.compact
          attrs["multiple"] = true if multiple
          attrs["disabled"] = true if disabled
          attrs["aria-invalid"] = "true" if invalid
          attrs.merge(stimulus_attributes_for(:control))
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "file-input", "data-variant" => variant }
              .merge(component_data_attributes).merge(stimulus_attributes_for(:root))
          )
        end

        def dropzone_attributes
          {
            "data-slot" => "file-input-dropzone",
            "class" => "#{css(:dropzone)}#{" #{css(:dropzone_disabled)}" if disabled}"
          }.merge(stimulus_attributes_for(:dropzone))
        end

        def list_attributes
          { "data-slot" => "file-input-list", "class" => css(:list) }
            .merge(stimulus_attributes_for(:list))
        end

        def clear_attributes
          { "type" => "button", "data-slot" => "file-input-clear", "hidden" => true,
            "class" => css(:clear) }
            .merge(stimulus_attributes_for(:clear))
        end
      end
    end
  end
end
