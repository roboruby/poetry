# frozen_string_literal: true

module Poetry
  module Ui
    # A styled native <select>.
    module NativeSelect
      # A styled REAL <select> - platform picker, form submission, and
      # mobile UX for free - with a decorative chevron replacing the
      # native arrow. The fast path is options: pairs; compose
      # <option>/<optgroup> in the content block for anything richer
      # (poetry_native_select_option / _optgroup stamp the classes).
      #
      # @example The options: fast path
      #   render Poetry::Ui::NativeSelect::Component.new(
      #     name: "sort", label: "Sort by",
      #     options: [["Newest first", "newest"], ["Oldest first", "oldest"]],
      #     selected: "newest"
      #   )
      class Component < Poetry::Core::Component
        # The closed vocabulary for the size axis.
        SIZES = %i[default sm].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "This is a REAL <select> - use it for plain picking; the JS Select is for styled options.",
          "Pair it with a Label (for_id: its id) or a Field - a bare select has no accessible name.",
          "The fast path is options: [[label, value], ...] + selected:; a content block overrides it."
        ].freeze

        option :name, :string, doc: "The submitted field name, forwarded to the native select."
        option :id, :string, doc: "The select's dom id - the seam a Label's for_id: points at."
        option :label, :string,
               doc: "The accessible name for label-less placements (a visible Label paired via id:/for_id: is still " \
                    "the default pattern)."
        option :size, :symbol, default: :default, doc: "The control size axis; :sm suits dense toolbars and table rows."
        option :disabled, :boolean, default: false, doc: "Disables the native select; the wrapper dims the whole pair."
        option :invalid, :boolean, default: false, doc: "Marks the select invalid (aria-invalid on the element itself)."
        option :described_by, :string,
               doc: "Space-separated hint/error ids wired to the SELECT itself - a raw aria-describedby in " \
                    "html_attributes would land on the wrapper div, unassociated for assistive technology."

        validates :size, inclusion: { in: SIZES }

        part "native-select-wrapper", "Relative shell around the select and the chevron - " \
                                      "dims the pair when the select is disabled",
             states: {
               "data-size" => { condition: "always - the resolved size",
                                values: SIZES.map(&:to_s) }
             }
        part "native-select", "The real <select> - appearance-none (the chevron replaces the " \
                              "native arrow); platform picker and form submission stay native",
             states: {
               "data-size" => { condition: "always - the resolved size (mirrors the wrapper)",
                                values: SIZES.map(&:to_s) }
             }
        part "native-select-icon", "The decorative chevron wrapper - absolutely pinned, " \
                                   "aria-hidden"
        part "native-select-option", "An <option> from the options: fast path (or " \
                                     "poetry_native_select_option) - Canvas system colors " \
                                     "keep the native dropdown legible"

        # @api private
        def call
          content_tag(:div, wrapper_attributes.to_attributes) do
            safe_join([select_element, chevron])
          end
        end

        # @api private
        def wrapper_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "native-select-wrapper", "data-size" => size
            }.merge(component_data_attributes)
          )
        end

        # @api private
        def select_attributes
          attrs = { "data-slot" => "native-select", "data-size" => size, "class" => css(:select) }
          attrs["name"] = name if name.present?
          attrs["id"] = id if id.present?
          attrs["aria-label"] = label if label.present?
          attrs["aria-describedby"] = described_by if described_by.present?
          attrs["disabled"] = true if disabled
          attrs["aria-invalid"] = true if invalid
          attrs
        end

        private

        # options: pairs are structural data, not a typed option.
        def initialize(options: nil, selected: nil, **)
          super(**)
          @options = options
          @selected = selected
        end

        def select_element
          content_tag(:select, select_content, select_attributes)
        end

        def select_content
          return content if content.present?

          safe_join(Array(@options).map do |entry|
            label, value = entry.is_a?(Array) ? entry : [entry, entry]
            tag.option(label, value: value, selected: value.to_s == @selected.to_s || nil,
                              "data-slot": "native-select-option", class: css(:option))
          end)
        end

        # The chevron svg is the icon part itself (the source's shape) - the
        # theme rule sizes and pins it; no wrapper span.
        def chevron
          render(Poetry::Ui::Icon::Component.new(name: :"chevron-down", class: css(:icon),
                                                 data: { slot: "native-select-icon" }))
        end

        private :wrapper_attributes, :select_attributes
      end
    end
  end
end
