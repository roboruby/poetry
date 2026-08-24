# frozen_string_literal: true

module Poetry
  module Ui
    module Command
      # The Command palette inside a modal dialog - the app-wide "press
      # Cmd+K" search. The native <dialog> focus trap does the overlay
      # work; the dialog's title and description are screen-reader-only
      # (localized defaults name the dialog), so the visible surface is
      # the palette itself.
      #
      # The global hotkey is OPT-IN (hotkey: "meta+k") and toggles the
      # dialog from anywhere; the trigger button remains the visible way
      # in. Items use Command's contract: act on poetry:command:select.
      #
      # @example
      #   render Poetry::Ui::Command::DialogComponent.new(hotkey: "meta+k") do |dialog|
      #     dialog.with_trigger(variant: :outline) { "Open palette" }
      #     dialog.with_item(value: "settings") { "Settings" }
      #   end
      class DialogComponent < Poetry::Core::Component
        # The palette surface delegates to the embedded Command - callers
        # use the same slot API as bare poetry_command.
        delegate :with_item, :with_group, :with_separator, :with_empty, :with_loading, to: :command

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "App-wide palettes use poetry_command_dialog with hotkey: ('meta+k') - never a hand-wired " \
          "window keydown listener around poetry_dialog.",
          "Open it with with_trigger(...) too - the hotkey is an accelerator, not the only way in.",
          "The sr-only title/description default to the source strings - override title:/description: " \
          "rather than removing them (they are the dialog's accessible name).",
          "Item wiring is Command's: act on poetry:command:select; close the dialog in the listener if " \
          "the action should dismiss the palette."
        ].freeze

        # The trigger is a poetry Button wired to open - the Dialog
        # pattern: with_trigger(variant: :outline) { "Open palette" }.
        renders_one :trigger, lambda { |**options, &block|
          options[:data] = { action: stimulus_action(:open) }.merge(options[:data] || {})
          Button::Component.new(**options, &block)
        }

        # The SHARED dialog controller (zero new JS) - hotkey included.
        use_stimulus do
          on :root do
            controller :dialog do
              register
              value :dismissible
              value :hotkey, if: -> { hotkey.present? }
            end
          end
          on :content do
            controller :dialog do
              target :dialog
              action :close, on: :cancel
              action :backdrop_close, on: :click
            end
          end
          on :trigger do
            controller(:dialog) { action :open }
          end
          on :close do
            controller(:dialog) { action :close }
          end
        end

        # The dialog's sr-only accessible name (localized default) -
        # override rather than remove.
        option :title, :string, default: -> { I18n.t("poetry.command.dialog_title") }
        # The sr-only description wired to aria-describedby (localized
        # default).
        option :description, :string, default: -> { I18n.t("poetry.command.dialog_description") }
        # A global shortcut ("meta+k") that toggles the palette from
        # anywhere; an accelerator, not the only way in.
        option :hotkey, :string
        # Renders the corner X (Esc always closes regardless).
        option :show_close_button, :boolean, default: true
        # Backdrop clicks close the palette; false keeps it open.
        option :dismissible, :boolean, default: true
        # Passed through to the embedded Command: client-side filtering.
        option :filter, :boolean, default: true
        # Passed through: wraps arrow-key highlight movement at the ends.
        option :loop, :boolean, default: false
        # Passed through: the filter input's placeholder text.
        option :placeholder, :string
        # Passed through: the listbox's accessible name.
        option :list_label, :string
        # Passed through: seats the initial highlight on this item value.
        option :value, :string
        # Passed through: the embedded palette's base DOM id.
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
        # @api private
        def self.component_title
          "command-dialog"
        end

        # The embedded Command, carrying the h-12 dialog override chain
        # (rewritten onto data-slots).
        # @api private
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

        # The sr-only title's id - the dialog's aria-labelledby target.
        # @api private
        def title_id
          "#{instance_id}-title"
        end

        # The sr-only description's id - the aria-describedby target.
        # @api private
        def description_id
          "#{instance_id}-description"
        end

        # Attributes for the root wrapper.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "command-dialog" }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        # Dialog's content chrome retuned for the palette (overflow-hidden
        # p-0 win on conflicts); labelled/described by the sr-only header.
        # @api private
        def dialog_attributes
          {
            "class" => Poetry::Ui::Dialog::Style.css(:content, class: Style.css(:dialog_content)),
            "data-slot" => "dialog-content",
            "data-closed" => "",
            "aria-labelledby" => title_id,
            "aria-describedby" => description_id
          }.merge(stimulus_attributes_for(:content))
        end

        # Validated action descriptor for the template's close button.
        # @api private
        def close_action
          stimulus_action(:close)
        end

        private

        # (Descriptor strings resolve through the declared elements above,
        # never through hand-written wiring.)

        # Server-stable unique id for the aria wiring (two palettes on one
        # page must not share label ids).
        def instance_id
          @instance_id ||= poetry_instance_id("poetry-command-dialog")
        end
      end
    end
  end
end
