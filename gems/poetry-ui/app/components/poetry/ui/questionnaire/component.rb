# frozen_string_literal: true

module Poetry
  module Ui
    module Questionnaire
      # The Questionnaire - shadcn's one-question-at-a-time survey
      # composite (their @shadcn/react primitive), ported form-native: the
      # root IS a real form (form_with), items are fieldsets with legend
      # titles, choices are native radio/checkbox inputs, and the free
      # text answer is a real input - the whole thing serializes as
      # ordinary Rails params with zero JS. The server renders the
      # complete initial state (active item, statuses, shortcut labels,
      # button visibility); the poetry--core--questionnaire controller
      # owns the runtime transitions.
      #
      # Rails divergence, on purpose: multiple-selection items name their
      # checkboxes "<name>[]" so params arrive as arrays - upstream's
      # FormData reads repeated bare names.
      class Component < Poetry::Core::Component
        SHORTCUT_MODES = %i[letters numbers].freeze
        SHORTCUT_KEYS = {
          letters: ("A".."Z").to_a,
          numbers: ("1".."9").to_a
        }.freeze

        AGENT_RULES = [
          "The root is a REAL form (url:/method:) - answers submit as ordinary params; " \
          "validate server-side and re-render invalid items with error:.",
          "One with_item per question (name: is the param key); choices via item.with_choice, " \
          "an optional free-text answer via item.with_input.",
          "multiple: true renders checkboxes named <name>[] (Rails array params) - " \
          "a recorded divergence from upstream's repeated bare names.",
          "required: true gates Next/submit client-side; the server stays the truth on submit.",
          "shortcuts: :letters or :numbers labels each choice with a key (server-rendered) " \
          "and enables one-keystroke answering.",
          "Skip renders only while the active item is optional - never force-hide it.",
          "with_progress { custom } replaces the readout; data-current/data-total on the " \
          "progress element and a [data-progress-count] child stay live for segment bars " \
          "and counters."
        ].freeze

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

        option :url, :string, required: true
        # Named http_method (not method:) - an option named `method` would
        # shadow Object#method.
        option :http_method, :symbol, default: :post
        option :id, :string
        # nil (off), :letters (A, B, C...) or :numbers (1-9): server-
        # rendered key labels + one-keystroke answering.
        option :shortcuts, :symbol
        # The initially active item by name; default is the first item.
        option :default_item, :string
        option :previous_label, :string, default: "Previous"
        option :skip_label, :string, default: "Skip"
        option :next_label, :string, default: "Next"
        option :submit_label, :string, default: "Submit"

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

        Choice = Struct.new(:value, :label, :description, :checked, :disabled, keyword_init: true)
        TextInput = Struct.new(:label, :placeholder, :value, keyword_init: true)

        # One question: title/description as args, choices and the
        # optional free-text input via the yielded builder.
        class Item
          attr_reader :name, :title, :description, :required, :multiple, :disabled,
                      :error, :choices, :input, :class_name

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

          def with_choice(value:, label:, description: nil, checked: false, disabled: false)
            @choices << Choice.new(value: value, label: label, description: description,
                                   checked: checked, disabled: disabled)
            self
          end

          def with_input(label:, placeholder: nil, value: nil)
            @input = TextInput.new(label: label, placeholder: placeholder, value: value)
            self
          end

          def default_error
            if required
              "Choose an answer to continue."
            else
              "Choose an answer or skip this question."
            end
          end

          def error_message = error || default_error

          def answered?
            choices.any?(&:checked) || input&.value.to_s.strip != ""
          end

          def status = answered? ? "answered" : "unanswered"
        end

        # with_progress (bare) renders the auto "Question X of Y" text;
        # with_progress { custom } replaces it (marked data-custom so the
        # controller leaves it alone).
        renders_one :progress

        # Hand-rolled (not a VC slot): the yielded builder is a plain
        # object, and ViewComponent lambda slots only forward to component
        # returns - a builder return wraps as nil.
        def with_item(**, &block)
          item = Item.new(**)
          block&.call(item)
          item_models << item
          item
        end

        def item_models = (@item_models ||= [])

        def before_render
          # Evaluate the composition block first - with_item is hand-rolled
          # (not a VC slot), so nothing else forces the block this early.
          content
          raise ArgumentError, "Questionnaire needs at least one with_item" if item_models.empty?
        end

        def questionnaire_id
          @questionnaire_id ||= "questionnaire-#{dom_id_token(id) || SecureRandom.hex(4)}"
        end

        def enabled_items = item_models.reject(&:disabled)

        def active_item
          @active_item ||= enabled_items.find { |item| item.name == default_item } ||
                           enabled_items.first
        end

        def active_index = enabled_items.index(active_item) || 0

        def first? = active_index.zero?
        def last? = active_index >= enabled_items.size - 1

        def progress_label
          "Question #{active_index + 1} of #{enabled_items.size}"
        end

        def shortcuts_string = shortcuts.to_s

        # Server-side shortcut assignment (the SSR-faithful half): keys in
        # document order per item; the controller only handles keystrokes.
        def shortcut_for(_item, index)
          return nil unless shortcuts

          SHORTCUT_KEYS.fetch(shortcuts)[index]
        end

        def item_dom_id(item, suffix)
          "#{questionnaire_id}-#{item.name.to_s.parameterize}-#{suffix}"
        end

        def field_name(item) = item.multiple ? "#{item.name}[]" : item.name.to_s

        def input_type(item) = item.multiple ? "checkbox" : "radio"

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "questionnaire", "id" => questionnaire_id }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

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
      end
    end
  end
end
