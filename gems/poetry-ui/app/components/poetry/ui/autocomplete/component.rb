# frozen_string_literal: true

module Poetry
  module Ui
    # Free-text inputs with filtering suggestion popups.
    module Autocomplete
      # A text input that suggests from a server-rendered list, filtered
      # as you type, while the text itself stays the form value: free text
      # submits as an ordinary param, and picking a suggestion writes it
      # into the input and closes the popup. When the value must be a
      # selected item rather than free text, use Combobox instead.
      #
      # @example Free text with suggestions
      #   render Poetry::Ui::Autocomplete::Component.new(name: "tag", label: "Search tags") do |auto|
      #     auto.with_item(label: "feature")
      #     auto.with_item(label: "fix")
      #   end
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
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

        option :name, :string, required: true, doc: "The form param key; the input's text submits under it as-is."
        option :value, :string, doc: "The initial input text."
        option :id, :string, doc: "Stable DOM id token for the root and list ids."
        option :placeholder, :string, doc: "Placeholder text shown while the input is empty."
        option :label, :string, doc: "The accessible name (or wire aria-labelledby via html attrs)."
        option :empty_text, :string, default: "No results.",
                                     doc: "The no-matches message; hidden while anything matches."
        option :open, :boolean, default: false, doc: "Server-renders the suggestion popup open."
        option :open_on_focus, :boolean, default: true, doc: "Opens the suggestions on focus; false waits for typing."

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

        # Forces the composition block so with_item calls land before the template renders.
        # @api private
        def before_render
          content
        end

        # Hand-rolled builder: ViewComponent lambda slots nil-wrap
        # non-component returns, so the builder collects plain models and
        # before_render forces the composition block.

        # Adds one suggestion to the popup list.
        #
        # @param label [String] what filtering matches and what commit writes into the input
        # @param value [String, nil] overrides the committed text when it differs from the label
        # @param disabled [Boolean] skipped by filtering and commit
        # @param highlighted [Boolean] server-renders the item highlighted
        def with_item(label:, value: nil, disabled: false, highlighted: false)
          item_models << Item.new(label: label, value: value, disabled: disabled,
                                  highlighted: highlighted)
          self
        end

        # The collected suggestion models.
        # @api private
        def item_models = (@item_models ||= [])

        # @api private
        def autocomplete_id
          @autocomplete_id ||= if (token = dom_id_token(id))
                                 "poetry-autocomplete-#{token}"
                               else
                                 poetry_instance_id("poetry-autocomplete")
                               end
        end

        # @api private
        def list_id = "#{autocomplete_id}-list"

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "class" => css, "data-slot" => "autocomplete", "id" => autocomplete_id }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        # @api private
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

        # @api private
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

        # @api private
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

        # One suggestion's plain data model, collected by with_item.
        # @api private
        Item = Struct.new(:label, :value, :disabled, :highlighted, keyword_init: true)

        private :item_models, :autocomplete_id, :list_id, :root_attributes, :input_attributes, :content_attributes
        private :item_attributes
      end
    end
  end
end
