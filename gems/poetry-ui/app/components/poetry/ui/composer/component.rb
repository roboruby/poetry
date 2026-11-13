# frozen_string_literal: true

module Poetry
  module Ui
    # The chat composer: the message form and the Send/Stop slot the server redraws.
    module Composer
      # A chat message composer: one form holding a growing textarea, a
      # tools row and an action slot that shows Send or Stop. Reach for it
      # wherever a person writes to a model or to another person.
      #
      # The server holds the running state. Render status: from your own
      # record, and when it changes redraw the slot alone -
      # poetry_composer_action(id:, status:) in a Turbo Stream that replaces
      # "<id>-action". The form and the field are never replaced, so a draft
      # typed while a reply streams is kept. A Stop button on the page is
      # the whole fact that a reply is running: the controller holds no copy
      # of it.
      #
      # Stop is a second small form of its own (stop_url:, a POST), so
      # stopping never sends the draft. Enter sends and Shift+Enter breaks
      # the line; an Enter that confirms an input-method composition does
      # not send. Nothing is sent while the field is blank, while a reply
      # runs, or while a send is already on its way. When the server accepts
      # a message the sent text leaves the field; a refused message (any
      # answer that is not a success) stays whole. The field grows with its
      # content by CSS up to a ceiling, then scrolls. Without JavaScript it
      # is a plain form with a submit button.
      #
      # @example A chat's composer
      #   render Poetry::Ui::Composer::Component.new(
      #     id: "composer", url: chat_messages_path(chat), name: "content",
      #     status: chat.composer_status, stop_url: stop_chat_path(chat)
      #   )
      class Component < Poetry::Core::Component
        include ActionWiring

        # The closed vocabulary for the status axis.
        STATUSES = %i[idle running stopping].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "The SERVER holds the running state: render status: from your record (:idle, :running, " \
          ":stopping) and redraw the slot alone with poetry_composer_action(id:, status:) in a Turbo " \
          "Stream replace of \"<id>-action\" - never replace the form or the field, the draft lives there.",
          "Send every status change down ONE ordered channel (the broadcast), or pass version: and use a " \
          "versioned replace - a form's answer and a broadcast can arrive out of order and leave Stop on screen.",
          "stop_url: is a POST endpoint that asks the reply to stop; a status other than :idle needs it. " \
          "The Stop button submits a form of its own, so the draft is never sent with it.",
          "Refuse a send on the server while a reply runs (answer 409 or 422): the field keeps its text " \
          "whenever the answer is not a success, and clears the sent text when it is.",
          "Block content is the tools row beside Send (attach, a model picker) - buttons there are " \
          "type: :button so they never submit the message.",
          "name: is the message's param key; label: is the field's accessible name - the placeholder " \
          "is not a label."
        ].freeze

        option :id, :string, required: true,
                             doc: "The composer's DOM id. The parts derive theirs from it: \"<id>-form\", " \
                                  "\"<id>-input\", \"<id>-stop\", and \"<id>-action\" - the slot a Turbo " \
                                  "Stream replaces."
        option :url, :string, required: true, doc: "Where the message posts - the form's action."
        option :http_method, :symbol, default: :post,
                                      doc: "The form's HTTP verb. Named http_method (not method:) - an option named " \
                                           "`method` would shadow Object#method."
        option :name, :string, default: "message", doc: "The param key the message text arrives under."
        option :value, :string, doc: "A draft to open with, rendered as the field's content."
        option :placeholder, :string, doc: "Hint text shown while the field is empty - never a substitute for label:."
        option :label, :string, doc: "The field's accessible name (aria-label). Defaults to the locale's \"Message\"."
        option :input_class, :string,
               doc: "Classes merged onto the field - min-h-24 opens it taller, max-h-80 raises the ceiling " \
                    "it grows to before it scrolls."
        option :status, :symbol, default: :idle,
                                 doc: "What the action slot shows: Send (:idle), Stop (:running), or Stop busy and " \
                                      "disabled (:stopping). Render it from your own record of the reply."
        option :stop_url, :string,
               doc: "Where the Stop button posts. Required for any status but :idle; the composer renders " \
                    "a hidden form for it beside the message form."
        option :version, :integer,
               doc: "A number that rises with every status change, rendered on the action slot as data-version " \
                    "for a versioned replace to compare. Leave it out when one ordered channel carries the status."
        option :submit_on_enter, :boolean, default: true,
                                           doc: "Enter sends and Shift+Enter breaks the line. false makes Enter " \
                                                "a line break; Cmd/Ctrl+Enter sends either way."
        option :disabled, :boolean, default: false, doc: "Disables the field and the Send button."
        option :send_label, :string,
               doc: "The Send button's accessible name. Defaults to the locale's \"Send message\"."
        option :stop_label, :string, doc: "The Stop button's accessible name. Defaults to the locale's \"Stop\"."

        validates :status, inclusion: { in: STATUSES }

        use_stimulus do
          # A morph puts the server's data-empty back on the root while the
          # field keeps its draft; the controller reads the field again.
          on :root do
            controller :composer do
              register
              value :submit_on_enter
              action :changed, on: :"turbo:morph-element"
            end
          end
          # The gate and the settle both ride the message form: the Stop
          # form is a sibling, so its submissions never reach them.
          on :form do
            controller :composer do
              target :form
              action :guard, on: :submit
              action :settle, on: :"turbo:submit-end"
            end
          end
          on :input do
            controller :composer do
              target :input
              action :keydown, on: :keydown
              action :changed, on: :input
            end
          end
        end

        part "composer", "The root - holds the message form and the Stop form; the controller and " \
                         "the emptiness state ride here",
             states: {
               "data-empty" => "the field holds nothing but whitespace (server-set, controller-kept) - " \
                               "the Send button dims"
             }
        part "composer-form", "The message <form> - never replaced. Turbo marks it aria-busy while a " \
                              "send is in flight"
        part "composer-group", "The bordered field surface - InputGroup's chrome, focus ring keyed " \
                               "on the control inside"
        part "input-group-control", "The native <textarea> - InputGroup's control slot (the themes' " \
                                    "focus-ring hook); grows with its content by CSS up to a ceiling"
        part "input-group-addon", "The footer row under the field - the tools (block content) and " \
                                  "the action slot",
             states: {
               "data-align" => { condition: "always - the row sits under the field",
                                 values: %w[block-end] }
             }
        part "composer-action", "The slot the server redraws (dom id <id>-action) - holds Send or " \
                                "Stop. poetry_composer_action renders exactly this element",
             states: {
               "data-running" => "status :running or :stopping - a Stop button is in the slot",
               "data-stopping" => "status :stopping - the Stop button is busy and disabled",
               "data-version" => "version: was given - the number a versioned replace compares"
             }
        part "composer-stop-form", "The hidden <form> the Stop button submits (dom id <id>-stop) - " \
                                   "rendered when stop_url: is given"
        # Send and Stop render as composed Buttons carrying
        # data-slot=composer-send / composer-stop on Button's root - part
        # ownership attributes them to Button, so they are documented here
        # in prose only: Send is the message form's submit button; Stop
        # names the Stop form through its form attribute.

        # Refuses a status the composer cannot act on.
        # @api private
        def before_render
          return if status == :idle || stop_url.present?

          raise ArgumentError, "Composer status: #{status.inspect} needs stop_url: (the Stop button posts there)"
        end

        # The composer's DOM id as a safe token - every part's id derives from it.
        #
        # @return [String]
        def composer_id
          @composer_id ||= dom_id_token(id) ||
                           raise(ArgumentError, "Composer id: #{id.inspect} has no usable characters")
        end

        # The root's attributes: this component's markup over the core default.
        def root_attributes
          attrs = { "id" => composer_id }
          attrs["data-empty"] = "" if value.to_s.strip.empty?
          super(attrs)
        end

        # The message form's attributes with its wiring.
        # @api private
        def form_attributes
          element_attributes(:form, { "id" => "#{composer_id}-form" })
        end

        # The bordered shell wearing InputGroup's chrome.
        # @api private
        def group_attributes
          element_attributes(:group, { "role" => "group", "class" => InputGroup::Style.css })
        end

        # The field's attributes: name, id, accessible name, classes and wiring.
        # @api private
        def input_attributes
          attrs = {
            "id" => "#{composer_id}-input",
            "name" => name,
            # One row where the field cannot size itself to its content;
            # where it can, the floor and the ceiling are the classes below.
            "rows" => 1,
            "data-slot" => "input-group-control",
            "class" => classnames(Textarea::Style.css, InputGroup::Style.css(:control_textarea), css(:input),
                                  input_class),
            "aria-label" => label.presence || t("poetry.composer.label"),
            "enterkeyhint" => submit_on_enter ? "send" : "enter"
          }
          attrs["placeholder"] = placeholder if placeholder.present?
          attrs["disabled"] = "" if disabled
          element_attributes(:input, attrs)
        end

        # The footer row's attributes: InputGroup's block-end addon.
        # @api private
        def footer_attributes
          element_attributes({
                               "data-slot" => "input-group-addon", "data-align" => "block-end",
                               "class" => InputGroup::Style.css(:addon, class: InputGroup::Style.css(:addon_block_end))
                             })
        end

        # The action slot, built from the same options the standalone helper takes.
        # @api private
        def action
          Action.new(id: composer_id, status: status, version: version, disabled: disabled,
                     send_label: send_label, stop_label: stop_label)
        end

        # The Stop form's attributes: hidden, and named for the Stop button's form attribute.
        # @api private
        def stop_form_attributes
          element_attributes(:stop_form, { "id" => "#{composer_id}-stop", "hidden" => "" })
        end

        private :form_attributes, :group_attributes, :input_attributes, :footer_attributes, :action,
                :stop_form_attributes
      end
    end
  end
end
