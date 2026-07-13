# frozen_string_literal: true

module Poetry
  module Ui
    module Command
      # The CommandDialog variant (Command): the ⌘K
      # palette - a Command inside the platform Dialog chrome. Like
      # AlertDialog, it reuses the poetry--core--dialog controller and the
      # native <dialog> + showModal() trap UNCHANGED with its own template
      # (Dialog's fixed visible header can't be made sr-only from outside -
      # the pragmatic AlertDialog-precedent call): the header is sr-only
      # (title/description default to the source strings via i18n), the
      # content wears Dialog's chrome retuned to overflow-hidden p-0, and
      # the embedded Command carries the h-12 override chain. The global
      # hotkey is OPT-IN (hotkey: "meta+k") - the dialog controller's
      # window listener toggles the dialog; shadcn leaves this to a caller
      # useEffect, poetry ships it because every consumer writes the same
      # ten lines. The embedded Command's input rides the
      # t('poetry.command.input_label') aria-label (the dialog's sr-only
      # title names the DIALOG, not the input).
      class DialogComponent < Poetry::Core::Component
        AGENT_RULES = [
          "App-wide palettes use poetry_command_dialog with hotkey: ('meta+k') - never a hand-wired " \
          "window keydown listener around poetry_dialog.",
          "Open it with with_trigger(...) too - the hotkey is an accelerator, not the only way in.",
          "The sr-only title/description default to the source strings - override title:/description: " \
          "rather than removing them (they are the dialog's accessible name).",
          "Item wiring is Command's: act on poetry:command:select; close the dialog in the listener if " \
          "the action should dismiss the palette."
        ].freeze

        # The SHARED dialog controller (zero new JS) - hotkey included.
        DIALOG = %i[poetry core dialog].freeze

        option :title, :string, default: -> { I18n.t("poetry.command.dialog_title") }
        option :description, :string, default: -> { I18n.t("poetry.command.dialog_description") }
        option :hotkey, :string
        option :show_close_button, :boolean, default: true
        option :dismissible, :boolean, default: true
        # Command passthrough (the embedded palette's options).
        option :filter, :boolean, default: true
        option :loop, :boolean, default: false
        option :placeholder, :string
        option :list_label, :string
        option :value, :string
        option :id, :string

        part "command-dialog", "Root wrapper around the trigger and the <dialog> - the " \
                               "palette's own chrome; the embedded Command inside carries its " \
                               "own part contract"
        # The dialog-* parts below are Dialog's panel chrome REUSED (same
        # controller, own template) - declared here because this component
        # renders them itself, retuned for the palette.
        part "dialog-content", "The <dialog> panel (Dialog's chrome retuned to overflow-hidden " \
                               "p-0) - positioning, animation, and the open state ride here",
             states: {
               "data-open" => "panel is open (the dialog controller flips the pair at runtime)",
               "data-closed" => "panel is closed or animating out (the server-rendered state)"
             }
        part "dialog-header", "Dialog's title block, sr-only here - the palette owns the " \
                              "visible surface"
        part "dialog-title", "The sr-only heading - the dialog's accessible name (defaults to " \
                             "the source string)"
        part "dialog-description", "The sr-only description wired to aria-describedby"

        # data-component self-id: "command-dialog", not the path-derived
        # "dialog" (which would shadow Dialog's own self-identification).
        def self.component_title
          "command-dialog"
        end

        # The trigger is a poetry Button wired to open - the Dialog
        # pattern: with_trigger(variant: :outline) { "Open palette" }.
        renders_one :trigger, lambda { |**options, &block|
          options[:data] = { action: stimulus.action(:open) }.merge(options[:data] || {})
          Button::Component.new(**options, &block)
        }

        # The palette surface delegates to the embedded Command - callers
        # use the same slot API as bare poetry_command.
        delegate :with_item, :with_group, :with_separator, :with_empty, :with_loading, to: :command

        # The embedded Command, carrying the h-12 dialog override chain
        # (the source CommandDialog className, rewritten onto data-slots).
        def command
          @command ||= begin
            options = {
              filter: filter, loop: loop, value: value,
              class: Style.css(:dialog_overrides),
              "aria-label" => I18n.t("poetry.command.input_label")
            }
            options[:placeholder] = placeholder if placeholder.present?
            options[:list_label] = list_label if list_label.present?
            options[:id] = id if id.present?
            Component.new(**options)
          end
        end

        def title_id
          "#{instance_id}-title"
        end

        def description_id
          "#{instance_id}-description"
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "command-dialog" }
              .merge(stimulus_attributes do |dialog|
                dialog.register_controller
                dialog.with_value(:dismissible, dismissible)
                dialog.with_value(:hotkey, hotkey) if hotkey.present?
              end)
              .merge(component_data_attributes)
          )
        end

        # Dialog's content chrome with the source override (overflow-hidden
        # p-0 win on conflicts); labelled/described by the sr-only header.
        def dialog_attributes
          {
            "class" => Poetry::Ui::Dialog::Style.css(:content, class: Style.css(:dialog_content)),
            "data-slot" => "dialog-content",
            "data-closed" => "",
            "aria-labelledby" => title_id,
            "aria-describedby" => description_id
          }.merge(stimulus_attributes do |dialog|
            dialog.with_target(:dialog)
            dialog.with_action(:close, on: :cancel)
            dialog.with_action(:backdrop_close, on: :click)
          end)
        end

        # Validated action descriptor for the template's close button.
        def close_action
          stimulus.action(:close)
        end

        private

        # A manifest-validated Builder for descriptor strings (pure - never
        # touches the component's own html_attributes).
        def stimulus
          @stimulus ||= Poetry::Core::Stimulus::Builder.new(DIALOG, Poetry::Core::HTML::Attributes.new)
        end

        def stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          yield Poetry::Core::Stimulus::Builder.new(DIALOG, attrs)
          attrs.to_attributes
        end

        # Server-stable unique id for the aria wiring (two palettes on one
        # page must not share label ids).
        def instance_id
          @instance_id ||= "poetry-command-dialog-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
