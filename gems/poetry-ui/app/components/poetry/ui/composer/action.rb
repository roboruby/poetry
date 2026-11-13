# frozen_string_literal: true

module Poetry
  module Ui
    module Composer
      # The composer's action slot: the one element the server redraws.
      # It holds the Send button while idle and the Stop button while a
      # reply runs, and the composer's controller reads nothing else to
      # know which - a Stop button on the page is the running state.
      # poetry_composer_action renders it alone, for a Turbo Stream that
      # replaces "<id>-action"; the composer renders the same element
      # inside itself. internal_component!: anatomy, not a registered
      # component.
      #
      # @api private
      class Action < Poetry::Core::Component
        internal_component!
        include ActionWiring

        option :id, :string, required: true, doc: "The composer's DOM id - the slot is \"<id>-action\"."
        option :status, :symbol, default: :idle, doc: "Send (:idle), Stop (:running), or Stop busy (:stopping)."
        option :version, :integer, doc: "The number a versioned replace compares, rendered as data-version."
        option :disabled, :boolean, default: false, doc: "Disables the Send button."
        option :send_label, :string, doc: "The Send button's accessible name."
        option :stop_label, :string, doc: "The Stop button's accessible name."

        validates :status, inclusion: { in: Component::STATUSES }

        # Renders the slot with the button its status calls for.
        def call
          content_tag(:span, status == :idle ? send_button : stop_button, **slot_attributes)
        end

        private

        # The slot's own attributes: its id, the stamp a versioned replace
        # compares, and the running and stopping states.
        def slot_attributes
          attrs = { "id" => "#{id}-action", "data-slot" => "composer-action", "class" => Style.css(:action) }
          attrs["data-version"] = version if version
          attrs["data-running"] = "" unless status == :idle
          attrs["data-stopping"] = "" if status == :stopping
          attrs
        end

        # The message form's submit button, dimmed by the root while the field is empty.
        def send_button
          button = Button::Component.new({
            type: :submit, disabled: disabled, label: send_label.presence || t("poetry.composer.send"),
            class: button_class(Style.css(:send)), "data-slot" => "composer-send", "data-size" => "icon-sm"
          }.merge(stimulus_attributes_for(:send)))

          render(button) { render(Icon::Component.new(name: :"arrow-up")) }
        end

        # While stopping the button is busy: Button's loading state swaps
        # the glyph for its spinner and disables the control.
        def stop_button
          stopping = status == :stopping
          button = Button::Component.new({
            type: :submit, loading: stopping, label: stop_label.presence || t("poetry.composer.stop"),
            class: button_class, "form" => "#{id}-stop",
            "data-slot" => "composer-stop", "data-size" => "icon-sm"
          }.merge(stimulus_attributes_for(:stop)))

          stopping ? render(button) : render(button) { render(Icon::Component.new(name: :square)) }
        end

        # InputGroup's in-group button chrome at the icon-sm size, under the composer's own.
        def button_class(own = nil)
          group = InputGroup::Style
          group.css(:button, class: [group.css(:button_icon_sm), own].compact.join(" "))
        end
      end
    end
  end
end
