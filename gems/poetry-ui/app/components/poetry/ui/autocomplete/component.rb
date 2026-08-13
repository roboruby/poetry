# frozen_string_literal: true

module Poetry
  module Ui
    module Autocomplete
      # The Autocomplete (Base UI's Autocomplete, first-party composed):
      # a REAL text input that IS the form value, suggesting from a
      # server-rendered list that filters as you type. The sibling of
      # Combobox - there the value is a SELECTED ITEM behind a native
      # <select>; here the text itself submits as an ordinary param.
      # Selecting a suggestion writes the input and closes.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "The input IS the value: name: is the param key and free text submits as-is - " \
          "suggestions are conveniences, not constraints (constrained pick = Combobox).",
          "Items via with_item(label:) - label is what filtering matches and what commit " \
          "writes; value: overrides the committed text when it differs from the label.",
          "empty_text: renders the no-matches state (hidden while anything matches).",
          "open_on_focus: false waits for typing before suggesting.",
          "Server-side filtering stays yours: render fewer items on re-render - the client " \
          "filter only narrows what the server sent."
        ].freeze

        use_stimulus do
          on :root do
            controller :autocomplete do
              register
              value :open_on_focus, "false", if: -> { !open_on_focus }
            end
            controller(:popper) { register }
          end
          on :input do
            controller :autocomplete do
              target :input
              action :input, on: :input
              action :focus, on: :focus
              action :blurred, on: :focusout
              action :keydown, on: :keydown
            end
            controller(:popper) { target :anchor }
          end
          on :content do
            controller(:autocomplete) { target :content }
            controller(:popper) { target :content }
          end
          on :list do
            controller(:autocomplete) { target :list }
          end
          on :empty do
            controller(:autocomplete) { target :empty }
          end
          on :item do
            controller :autocomplete do
              action :itemPress, on: :pointerdown
              action :itemEnter, on: :pointerenter
            end
          end
        end

        option :name, :string, required: true
        option :value, :string
        option :id, :string
        option :placeholder, :string
        # The accessible name (or wire aria-labelledby via html attrs).
        option :label, :string
        option :empty_text, :string, default: "No results."
        option :open, :boolean, default: false
        option :open_on_focus, :boolean, default: true

        part "autocomplete", "Root wrapper carrying the controller + popper pair"
        part "autocomplete-input", "The REAL text input - role=combobox with aria-expanded " \
                                   "tracking the popup, the form value itself"
        part "autocomplete-content", "The popper-positioned popup shell",
             states: {
               "data-open" => "popup visible",
               "data-closed" => "popup hidden (the server-rendered default)",
               "data-empty" => "no item matches the query - the empty state shows"
             }
        part "autocomplete-list", "role=listbox holding the options"
        part "autocomplete-item", "One suggestion - role=option; commit writes its label " \
                                  "(or value:) into the input",
             states: {
               "data-label" => "always - what filtering matches and commit writes",
               "data-value" => "value: given - overrides the committed text",
               "data-highlighted" => "the keyboard/pointer highlight",
               "data-disabled" => "disabled: - skipped by filtering and commit"
             }
        part "autocomplete-empty", "The no-matches message (hidden while anything matches)"

        Item = Struct.new(:label, :value, :disabled, :highlighted, keyword_init: true)

        # Hand-rolled (the questionnaire lesson): ViewComponent lambda
        # slots nil-wrap non-component returns, so the builder collects
        # plain models and before_render forces the composition block.
        def with_item(label:, value: nil, disabled: false, highlighted: false)
          item_models << Item.new(label: label, value: value, disabled: disabled,
                                  highlighted: highlighted)
          self
        end

        def item_models = (@item_models ||= [])

        def before_render
          content
        end

        def autocomplete_id
          @autocomplete_id ||= "poetry-autocomplete-#{dom_id_token(id) || SecureRandom.hex(4)}"
        end

        def list_id = "#{autocomplete_id}-list"

        def root_attributes
          html_attributes.merge_if_not_set(
            { "class" => css, "data-slot" => "autocomplete", "id" => autocomplete_id }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        def input_attributes
          attrs = {
            name: name, value: value, placeholder: placeholder, type: :text,
            autocomplete: "off", role: "combobox",
            "aria-autocomplete": "list", "aria-expanded": open.to_s, "aria-controls": list_id,
            "data-slot": "autocomplete-input"
          }
          attrs[:"aria-label"] = label if label.present?
          attrs.merge(stimulus_attributes_for(:input).transform_keys(&:to_sym))
        end

        def content_attributes
          attrs = {
            "class" => css(:content), "data-slot" => "autocomplete-content"
          }
          if open
            attrs["data-open"] = ""
          else
            attrs["data-closed"] = ""
            attrs["hidden"] = "hidden"
          end
          attrs.merge(stimulus_attributes_for(:content))
        end

        def item_attributes(item, index)
          attrs = {
            "class" => Poetry::Ui::Command::Style.css(:item), "data-slot" => "autocomplete-item",
            "id" => "#{autocomplete_id}-item-#{index}", "role" => "option",
            "data-label" => item.label
          }
          attrs["data-value"] = item.value if item.value.present?
          attrs["data-highlighted"] = "" if item.highlighted
          attrs["data-disabled"] = "" if item.disabled
          attrs["aria-disabled"] = "true" if item.disabled
          attrs.merge(stimulus_attributes_for(:item))
        end
      end
    end
  end
end
