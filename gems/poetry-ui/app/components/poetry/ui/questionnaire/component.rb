# frozen_string_literal: true

module Poetry
  module Ui
    # A one-question-at-a-time survey form.
    module Questionnaire
      # A one-question-at-a-time survey. Reach for it when a flow asks
      # several questions in sequence and should submit as one form. The
      # root IS a real form (form_with), items are fieldsets with legend
      # titles, choices are native radio/checkbox inputs, and the free-text
      # answer is a real input - the whole thing serializes as ordinary
      # Rails params with zero JS. The server renders the complete initial
      # state (active item, statuses, shortcut labels, button visibility);
      # the controller owns the runtime transitions.
      #
      # Multiple-selection items name their checkboxes "<name>[]" so
      # params arrive as arrays.
      #
      # @example
      #   render Poetry::Ui::Questionnaire::Component.new(url: "/surveys") do |survey|
      #     survey.with_item(name: "mood", title: "How was your week?") do |item|
      #       item.with_choice(value: "good", label: "Good")
      #       item.with_choice(value: "bad", label: "Bad")
      #     end
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the shortcuts axis.
        SHORTCUT_MODES = %i[letters numbers].freeze
        # The key labels each shortcut mode assigns, in document order.
        SHORTCUT_KEYS = {
          letters: ("A".."Z").to_a,
          numbers: ("1".."9").to_a
        }.freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "The root is a REAL form (url:/method:) - answers submit as ordinary params; " \
          "validate server-side and re-render invalid items with error:.",
          "One with_item per question (name: is the param key); choices via item.with_choice, " \
          "an optional free-text answer via item.with_input.",
          "multiple: true renders checkboxes named <name>[] (Rails array params) - " \
          "a recorded divergence from the ported source's repeated bare names.",
          "required: true gates Next/submit client-side; the server stays the truth on submit.",
          "shortcuts: :letters or :numbers labels each choice with a key (server-rendered) " \
          "and enables one-keystroke answering.",
          "Skip renders only while the active item is optional - never force-hide it.",
          "with_progress { custom } replaces the readout; data-current/data-total on the " \
          "progress element and a [data-progress-count] child stay live for segment bars " \
          "and counters."
        ].freeze

        renders_one :progress, doc: "with_progress (bare) renders the auto \"Question X of Y\" text; with_progress " \
                                    "{ custom } replaces it (marked data-custom so the controller leaves it alone). " \
                                    "class: merges onto the progress element (e.g. w-full for a full-width segment " \
                                    "bar over the base w-fit)."
        alias __vc_with_progress with_progress

        # Opts the progress readout in. Bare, it renders the live
        # "Question X of Y" text; a block replaces the text; class: merges
        # onto the progress element.
        def with_progress(**options, &)
          @progress_class = options[:class]
          __vc_with_progress(&)
        end

        # @api private
        attr_reader :progress_class

        use_stimulus do
          on :root do
            controller :questionnaire do
              register
              value :shortcuts, from: :shortcuts_string, if: -> { shortcuts.present? }
              action :keydown, on: :keydown
              action :submit, on: :submit
              action :reset, on: :reset
              action :change, on: :change
              action :input, on: :input
            end
          end
          on :progress do
            controller(:questionnaire) { target :progress }
          end
          on :previous do
            controller :questionnaire do
              target :previous
              action :previous
            end
          end
          on :skip do
            controller :questionnaire do
              target :skip
              action :skip
            end
          end
          on :next_button do
            controller :questionnaire do
              target :next
              action :next
            end
          end
          on :submit_button do
            controller(:questionnaire) { target :submit }
          end
        end

        option :url, :string, required: true, doc: "The form's submit URL - answers post here as ordinary params."
        option :http_method, :symbol, default: :post,
                                      doc: "The form's HTTP verb. Named http_method (not method:) - an option named " \
                                           "`method` would shadow Object#method."
        option :id, :string, doc: "The root form's DOM id; item element ids derive from it."
        option :shortcuts, :symbol,
               doc: "nil (off), :letters (A, B, C...) or :numbers (1-9): server- rendered key labels + one-keystroke " \
                    "answering."
        option :default_item, :string, doc: "The initially active item by name; default is the first item."
        option :previous_label, :string, default: "Previous", doc: "The back-navigation button's text."
        option :skip_label, :string, default: "Skip",
                                     doc: "The skip button's text (shown only while the active item is optional)."
        option :next_label, :string, default: "Next", doc: "The forward-navigation button's text."
        option :submit_label, :string, default: "Submit",
                                       doc: "The final submit button's text (replaces Next on the last item)."

        validates :shortcuts, inclusion: { in: SHORTCUT_MODES }, allow_nil: true

        part "questionnaire", "The root <form> the controller drives - navigation, validation " \
                              "gating, and the keyboard map all ride here"
        part "questionnaire-progress", "The polite progressbar ('Question X of Y'; block " \
                                       "content replaces the text). Always carries live " \
                                       "data-current/data-total, and a [data-progress-count] " \
                                       "child gets the live 'X of Y' text - custom segment " \
                                       "bars ride data-[current=N] variants",
             states: {
               "data-custom" => "block content supplied - the controller leaves the text alone",
               "data-current" => "always - the active question number (live)",
               "data-total" => "always - the enabled question count (live)"
             }
        part "questionnaire-item", "One question <fieldset> - exactly one is active",
             states: {
               "data-name" => "always - the item's param name",
               "data-active" => "the visible question (inactive items are hidden + inert)",
               "data-status" => { condition: "always - the answer state",
                                  values: %w[unanswered answered skipped] },
               "data-required" => "required: true - Skip hides and Next validates",
               "data-multiple" => "multiple: true - checkbox choices named <name>[]",
               "data-invalid" => "validation attempted and unanswered - the error shows",
               "data-validated" => "a navigation has demanded this answer at least once",
               "data-skipped" => "explicitly skipped (cleared by any interaction)"
             }
        part "questionnaire-title", "The question heading - a real <legend>"
        part "questionnaire-description", "Muted copy under the title; its id rides the " \
                                          "fieldset's aria-describedby"
        part "questionnaire-choices", "The answer grid for one item"
        part "questionnaire-choice", "One answer <label> wrapping its native input",
             states: {
               "data-type" => { condition: "always - the input kind",
                                values: %w[radio checkbox] },
               "data-checked" => "the choice is selected",
               "data-unchecked" => "the choice is not selected",
               "data-shortcut" => "shortcuts: on - the key label (A, B... or 1-9)",
               "data-disabled" => "choice or item disabled"
             }
        part "questionnaire-choice-input", "THE native radio/checkbox - stretched invisibly " \
                                           "over the row (paste of the input-otp posture)",
             states: {
               "data-checked" => "selected", "data-unchecked" => "not selected"
             }
        part "questionnaire-choice-indicator", "The box/circle glyph (aria-hidden) - dot for " \
                                               "radio, check for checkbox"
        part "questionnaire-choice-indicator-dot", "The radio dot (shown while checked)"
        part "questionnaire-choice-indicator-check", "The checkbox check icon (shown while " \
                                                     "checked)"
        part "questionnaire-choice-label", "The label column - answer text over the optional " \
                                           "description"
        part "questionnaire-choice-description", "Muted copy under the answer text"
        part "questionnaire-choice-shortcut", "The key hint chip (aria-hidden; hidden unless " \
                                              "the choice carries data-shortcut)"
        part "questionnaire-input-wrapper", "The free-text answer's positioning wrapper"
        part "questionnaire-input", "The free-text answer - a real text input named after " \
                                    "the item",
             states: {
               "data-filled" => "has a value (counts as answered)",
               "data-empty" => "blank"
             }
        part "questionnaire-error", "The validation message (hidden until a navigation " \
                                    "demands the answer; role=alert while shown)"
        part "questionnaire-actions", "The navigation row - Previous / Skip / Next / Submit " \
                                      "(the buttons ride composed Buttons, so those elements " \
                                      "belong to Button's anatomy, not this contract; each " \
                                      "carries data-visible/data-hidden + hidden/inert)"

        # @api private
        def before_render
          # Evaluate the composition block first - with_item is hand-rolled
          # (not a VC slot), so nothing else forces the block this early.
          content
          raise ArgumentError, "Questionnaire needs at least one with_item" if item_models.empty?
        end

        # Adds one question. name: is the param key, title: the visible
        # heading; the yielded builder takes answers (with_choice) and an
        # optional free-text field (with_input).
        # Hand-rolled (not a VC slot): the yielded builder is a plain
        # object, and ViewComponent lambda slots only forward to component
        # returns - a builder return wraps as nil.
        def with_item(**, &block)
          item = Item.new(**)
          block&.call(item)
          item_models << item
          item
        end

        # @api private
        def item_models = (@item_models ||= [])

        # @api private
        def questionnaire_id
          @questionnaire_id ||= if (token = dom_id_token(id))
                                  "questionnaire-#{token}"
                                else
                                  poetry_instance_id("questionnaire")
                                end
        end

        # @api private
        def enabled_items = item_models.reject(&:disabled)

        # @api private
        def active_item
          @active_item ||= enabled_items.find { |item| item.name == default_item } ||
                           enabled_items.first
        end

        # @api private
        def active_index = enabled_items.index(active_item) || 0

        # @api private
        def first? = active_index.zero?
        # @api private
        def last? = active_index >= enabled_items.size - 1

        # @api private
        def progress_label
          "Question #{active_index + 1} of #{enabled_items.size}"
        end

        # @api private
        def shortcuts_string = shortcuts.to_s

        # Server-side shortcut assignment: keys in document order per item;
        # the controller only handles keystrokes.
        # @api private
        def shortcut_for(_item, index)
          return nil unless shortcuts

          SHORTCUT_KEYS.fetch(shortcuts)[index]
        end

        # @api private
        def item_dom_id(item, suffix)
          "#{questionnaire_id}-#{item.name.to_s.parameterize}-#{suffix}"
        end

        # @api private
        def field_name(item) = item.multiple ? "#{item.name}[]" : item.name.to_s

        # @api private
        def input_type(item) = item.multiple ? "checkbox" : "radio"

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "questionnaire", "id" => questionnaire_id }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        # @api private
        def item_attributes(item)
          active = item == active_item
          attrs = {
            "class" => css(:item, class: item.class_name), "data-slot" => "questionnaire-item",
            "data-name" => item.name, "data-status" => item.status,
            "aria-describedby" => (item.description ? item_dom_id(item, "description") : nil)
          }.compact
          attrs["data-active"] = "" if active
          attrs["hidden"] = "hidden" unless active
          attrs["inert"] = "inert" unless active
          attrs["data-required"] = "" if item.required
          attrs["data-multiple"] = "" if item.multiple
          attrs["disabled"] = "disabled" if item.disabled
          attrs
        end

        # Symbol-keyed Button kwargs for one nav action: part classes,
        # slot, wiring, and the server-rendered visibility stamp.
        # @api private
        def nav_button_options(kind, hidden:)
          stimulus_element = { next: :next_button, submit: :submit_button }.fetch(kind, kind)
          attrs = { class: css(kind), "data-slot": "questionnaire-#{kind}" }
          attrs.merge!(stimulus_attributes_for(stimulus_element).transform_keys(&:to_sym))
          if hidden
            attrs.merge!(hidden: true, inert: true, tabindex: -1,
                         "aria-hidden": "true", "data-hidden": "")
          else
            attrs[:"data-visible"] = ""
          end
          attrs
        end

        # @api private
        def choice_attributes(item, choice, index)
          attrs = {
            "class" => css(:choice), "data-slot" => "questionnaire-choice",
            "data-type" => input_type(item)
          }
          attrs[choice.checked ? "data-checked" : "data-unchecked"] = ""
          attrs["data-disabled"] = "" if choice.disabled || item.disabled
          if (key = shortcut_for(item, index))
            attrs["data-shortcut"] = key
          end
          attrs
        end

        # One answer row's data, built via Item#with_choice.
        # @api private
        Choice = Struct.new(:value, :label, :description, :checked, :disabled, keyword_init: true)
        # The free-text answer's data, built via Item#with_input.
        # @api private
        TextInput = Struct.new(:label, :placeholder, :value, keyword_init: true)

        # One question: title/description as args, choices and the
        # optional free-text input via the yielded builder.
        class Item
          attr_reader :name, :title, :description, :required, :multiple, :disabled,
                      :error, :choices, :input, :class_name

          # @api private
          def initialize(name:, title:, **options)
            @name = name
            @title = title
            @class_name = options[:class]
            @description = options[:description]
            @required = options.fetch(:required, false)
            @multiple = options.fetch(:multiple, false)
            @disabled = options.fetch(:disabled, false)
            @error = options[:error]
            @choices = []
            @input = nil
          end

          # Adds one answer to the question.
          # @param value [String] the submitted param value
          # @param label [String] the visible answer text
          # @param description [String, nil] muted copy under the answer text
          # @param checked [Boolean] pre-selects the answer
          # @param disabled [Boolean] renders the answer unpickable
          def with_choice(value:, label:, description: nil, checked: false, disabled: false)
            @choices << Choice.new(value: value, label: label, description: description,
                                   checked: checked, disabled: disabled)
            self
          end

          # Adds the optional free-text answer field, named after the item.
          # @param label [String] the field's accessible label
          # @param placeholder [String, nil] hint text while empty
          # @param value [String, nil] the pre-filled answer
          def with_input(label:, placeholder: nil, value: nil)
            @input = TextInput.new(label: label, placeholder: placeholder, value: value)
            self
          end

          # @api private
          def default_error
            if required
              "Choose an answer to continue."
            else
              "Choose an answer or skip this question."
            end
          end

          # @api private
          def error_message = error || default_error

          # @api private
          def answered?
            choices.any?(&:checked) || input&.value.to_s.strip != ""
          end

          # @api private
          def status = answered? ? "answered" : "unanswered"
        end
      end
    end
  end
end
