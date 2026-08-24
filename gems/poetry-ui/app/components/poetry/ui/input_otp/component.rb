# frozen_string_literal: true

module Poetry
  module Ui
    # The InputOtp family - fixed-length one-time-code entry.
    module InputOtp
      # Fixed-length one-time-code entry built around a single input:
      # there are NO per-cell inputs. One real
      # native <input> (autocomplete one-time-code) holds the whole value,
      # stretched invisibly over the row, so paste, SMS autofill, IME,
      # constraint validation and serialization are all native and
      # assistive technology
      # sees ONE text field. The n slot cells are a purely presentational
      # aria-hidden MIRROR painted by JS: auto-advance and
      # backspace-retreat are not features, they are the native caret
      # PROJECTED (data-active follows selectionStart).
      #
      # The server renders the value's chars into the cells AND the input
      # (no-JS honesty: typing/submitting works JS-free; only the live
      # cell paint needs the controller). The cell row forces dir=ltr -
      # codes are LTR strings, slot order == string index order even on
      # RTL pages.
      #
      # @example
      #   render Poetry::Ui::InputOtp::Component.new(name: "code", length: 6, groups: [3, 3])
      class Component < Poetry::Core::Component
        # The supported code lengths - cell UIs degrade past ~8.
        LENGTH_RANGE = (1..12)
        # The built-in per-char filters with their native pattern + inputmode.
        PATTERNS = {
          digits: { js: "\\d", char: "[0-9]", inputmode: "numeric" },
          alphanumeric: { js: "[a-zA-Z0-9]", char: "[a-zA-Z0-9]", inputmode: "text" }
        }.freeze
        # Field control_attributes land on the INPUT (the real control);
        # everything else the caller passes styles the container.
        INPUT_FACING = %w[id aria-label aria-describedby aria-invalid aria-required].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Use poetry_input_otp / form.otp_field - NEVER build per-cell inputs (n Tab stops, broken " \
          "paste, broken SMS autofill, unnameable cells).",
          "Label via Field always ('Verification code'); put the length in the hint.",
          "groups must sum to length (ArgumentError).",
          "Do NOT auto-submit on poetry:otp:complete without a visible confirm affordance - silent " \
          "submit on the 6th keystroke strands users who mistyped char 3.",
          "Never pre-fill value: with a real code in previews/test fixtures beyond dummies; never log " \
          "the value (it is a live credential).",
          "InputOTP is for CODES - passwords use Input type=password, longer identifiers use Input."
        ].freeze

        use_stimulus do
          on :root do
            controller :otp do
              register
              value :length
              value :pattern, from: :pattern_js
              # The input already covers the cells at z-20; this catches
              # gap/separator clicks.
              action :focus_input, on: :click
            end
          end
          on :input do
            controller :otp do
              target :input
              action :sync, on: %i[input focus blur]
              # maxlength truncates RAW clipboard text before the input
              # event - the controller filters the paste itself.
              action :paste, on: :paste
            end
          end
          on :slot do
            controller(:otp) { target :slot }
          end
        end

        option :name, :string, required: true, doc: "The ONE input serializes params[name] = the code string."
        option :length, :integer, required: true, doc: "Code length = slot count = maxlength."
        option :value, :string,
               doc: "Current code (server-rendered into the input AND the cells). The FormBuilder deliberately never " \
                    "round-trips it (a rejected code is dead)."
        option :groups, ActiveModel::Type::Value.new,
               doc: "Cell clustering, e.g. [3, 3] -> two groups with a separator."
        option :pattern, ActiveModel::Type::Value.new, default: :digits,
                                                       doc: ":digits (numeric keypad) | :alphanumeric | a custom " \
                                                            "Regexp - the per-char filter + the native pattern " \
                                                            "attribute + inputmode."
        option :disabled, :boolean, default: false, doc: "Disables the native input (the whole row dims)."
        option :required, :boolean, default: false,
                                    doc: "aria-required on the input - never native required (the Field rule: " \
                                         "required rides server-side validation + aria)."
        option :invalid, :boolean, default: false,
                                   doc: "aria-invalid on the input; the cells mirror the destructive treatment (set " \
                                        "by Field/FormBuilder from the failed verify)."
        option :separator, :boolean, default: true,
                                     doc: "role=separator dash between groups (meaningful with 2+ groups)."

        part "input-otp-container", "Root row (forced dir=ltr - slot order equals string index " \
                                    "order even on RTL pages) wrapping the real input and the " \
                                    "mirror cells"
        part "input-otp", "THE real native <input> (autocomplete one-time-code) stretched " \
                          "invisibly over the row - the only AT and serialization surface"
        part "input-otp-group", "One aria-hidden cluster of mirror cells (groups: clustering)"
        part "input-otp-slot", "One presentational mirror cell - paints its char and the " \
                               "active-cell ring",
             states: {
               "data-active" => { condition: "\"true\" while the native caret sits on this cell " \
                                             "(the controller projects selectionStart while the " \
                                             "input is focused; the server renders \"false\")",
                                  values: %w[true false] }
             }
        part "input-otp-caret", "The fake-caret overlay - hidden server-side; the controller " \
                                "unhides it on the active EMPTY cell"
        part "input-otp-separator", "The between-groups dash - role=separator kept for parity " \
                                    "but aria-hidden (a recorded divergence)"

        # Validates length, groups, and pattern up front.
        # @api private
        def initialize(attributes = {})
          super

          validate_length!
          validate_groups!
          pattern_spec # raises on garbage patterns up front
        end

        # The resolved cell clustering ([length] when groups: is absent).
        # @api private
        def group_sizes
          @group_sizes ||= (groups.presence || [length]).map { |size| Integer(size) }
        end

        # The value truncated to length, as rendered into input and cells.
        # @api private
        def display_value
          value.to_s[0, length].to_s
        end

        # The character painted into the cell at index ("" when empty).
        # @api private
        def char_at(index)
          display_value[index].to_s
        end

        # The native input's server-stable id.
        # @api private
        def input_id
          @input_id ||= poetry_instance_id("poetry-input-otp")
        end

        # Whether the rendered value already fills every cell.
        # @api private
        def complete?
          display_value.length >= length
        end

        # The row container's attributes.
        # @api private
        def root_attributes
          attrs = {
            "data-slot" => "input-otp-container",
            # Codes are LTR strings: slot order must equal string index
            # order even on RTL pages (the one place forcing ltr is right).
            "dir" => "ltr"
          }
          container_attributes.merge_if_not_set(
            attrs.merge(stimulus_attributes_for(:root)).merge(component_data_attributes)
          )
        end

        # The real native input's attributes.
        # @api private
        def input_attributes
          attrs = {
            "type" => "text", "name" => name, "id" => input_id,
            "maxlength" => length, "pattern" => html_pattern, "inputmode" => inputmode,
            "autocomplete" => "one-time-code", "spellcheck" => "false",
            "autocapitalize" => "off", "autocorrect" => "off",
            "data-slot" => "input-otp", "class" => css(:input)
          }
          # The invisible input is the ONLY AT surface - it must always
          # carry a name (the axe label rule); callers override via
          # aria-label / Field labelling.
          attrs["aria-label"] = t("poetry.input_otp.label")
          attrs["value"] = display_value if display_value.present?
          attrs["disabled"] = true if disabled
          attrs["aria-required"] = true if required
          attrs["aria-invalid"] = true if invalid
          Poetry::Core::HTML::Attributes.new(html_attributes.slice(*INPUT_FACING))
                                        .merge_if_not_set(attrs.merge(stimulus_attributes_for(:input)))
        end

        # One mirror cell's attributes.
        # @api private
        def slot_attributes(_index)
          attrs = {
            class: css(:slot), "data-slot" => "input-otp-slot", "data-active" => "false"
          }
          # Styling-only on an aria-hidden cell (the source's
          # aria-invalid: variants key on it); AT never sees it.
          attrs["aria-invalid"] = "true" if invalid
          attrs.merge(stimulus_attributes_for(:slot))
        end

        private

        # Everything NOT input-facing styles the container.
        def container_attributes
          Poetry::Core::HTML::Attributes.new(html_attributes.except(*INPUT_FACING))
        end

        def pattern_spec
          return PATTERNS.fetch(pattern.to_sym) if pattern.respond_to?(:to_sym) && PATTERNS.key?(pattern.to_sym)
          return { js: pattern.source, char: "(?:#{pattern.source})", inputmode: "text" } if pattern.is_a?(Regexp)

          raise ArgumentError, "InputOTP pattern: must be :digits, :alphanumeric, or a Regexp - " \
                               "got #{pattern.inspect}"
        end

        def html_pattern
          "#{pattern_spec[:char]}{#{length}}"
        end

        def inputmode
          pattern_spec[:inputmode]
        end

        def validate_length!
          return if LENGTH_RANGE.cover?(length)

          raise ArgumentError, "InputOTP length: must be in #{LENGTH_RANGE} (cell UIs degrade past ~8) - " \
                               "got #{length.inspect}"
        end

        def validate_groups!
          return if group_sizes.sum == length

          raise ArgumentError, "InputOTP groups: must sum to length (#{length}) - " \
                               "#{group_sizes.inspect} sums to #{group_sizes.sum}"
        rescue TypeError
          raise ArgumentError, "InputOTP groups: must be an array of integers - got #{groups.inspect}"
        end

        def pattern_js = pattern_spec[:js]

        private :group_sizes, :display_value, :char_at, :input_id, :complete?, :root_attributes, :input_attributes
        private :slot_attributes
      end
    end
  end
end
