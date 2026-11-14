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
      # attachments: true makes files part of the message. A paperclip
      # opens the picker, a file dropped on the composer or pasted into the
      # field lands in it, and every file shows as a chip above the field
      # that the reader can remove. The files post with the message under
      # attachments_name:, or as Active Storage signed ids with
      # direct_upload:. A message of files alone can be sent, and the chips
      # leave when the server accepts the message. Attaching needs
      # JavaScript.
      #
      # with_menu adds a list that opens over the composer while the word
      # being typed starts with its trigger: people behind "@", commands
      # behind "/". The server renders the options and the composer filters
      # them as the word grows; arrows move, Enter and Tab choose, Escape
      # closes. What reaches the server stays plain. A text menu leaves
      # "@ana " in the message; a chip menu (inserts: :chip) takes the typed
      # word out and posts the chosen value in a hidden field, with a chip
      # above the field; an item with run: true is only reported to the
      # page. The field stays a native textarea throughout.
      #
      # @example A composer with a people menu and a files menu
      #   render Poetry::Ui::Composer::Component.new(id: "composer", url: chat_messages_path(chat)) do |composer|
      #     composer.with_menu(trigger: "@", label: "People") do |menu|
      #       chat.members.each { |member| menu.with_item(value: member.handle, label: member.name) }
      #     end
      #     composer.with_menu(trigger: "#", label: "Files", inserts: :chip, name: "context[]", icon: :file) do |menu|
      #       chat.files.each { |file| menu.with_item(value: file.to_sgid.to_s, label: file.filename.to_s) }
      #     end
      #   end
      #
      # @example A chat's composer
      #   render Poetry::Ui::Composer::Component.new(
      #     id: "composer", url: chat_messages_path(chat), name: "content",
      #     status: chat.composer_status, stop_url: stop_chat_path(chat)
      #   )
      class Component < Poetry::Core::Component
        include ActionWiring
        include FileInput::Uploads
        include Menus

        # The closed vocabulary for the status axis.
        STATUSES = %i[idle running stopping].freeze
        # The closed vocabulary for upload: (when direct uploads run).
        UPLOAD_MODES = %i[on_submit immediate].freeze
        # The intake's rejection codes and upload messages are FileInput's:
        # one intake, one vocabulary.
        REJECTION_CODES = FileInput::Component::REJECTION_CODES
        # The upload messages the file-input controller shows, by translation key.
        UPLOAD_MESSAGES = FileInput::Component::UPLOAD_MESSAGES

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
          "Block content is the tools row beside Send (a model picker, a mode toggle) - buttons there " \
          "are type: :button so they never submit the message.",
          "Files in a message are attachments: true - the paperclip, drop, paste and the chips are the " \
          "composer's own; never put a FileInput or a hand-rolled file button in the tools row. The files " \
          "arrive under attachments_name: (\"attachments[]\"), or as signed ids with direct_upload: true.",
          "accept:, max_size: and max_files: refuse a file at intake and are advisory: validate the " \
          "attachment on the model as well.",
          "A mention or command menu is composer.with_menu(trigger:, label:) with menu.with_item per " \
          "option: the server renders every option and the composer filters them as the word is typed. " \
          "Never hand-roll a popup over the field or swap the textarea for an editable div.",
          "What a menu sends is plain: a text menu leaves \"@value \" in the message (or the item's " \
          "insert:), a chip menu (inserts: :chip, name:) posts the chosen values as hidden fields under " \
          "name: and leaves the text clean. Never invent bracket or directive syntax for a reference, and " \
          "look the handle or the value up again on the server.",
          "Commands: at: :start opens the menu only on the message's first word; insert: \"/summarize \" " \
          "leaves text the server reads from the start of the message, and run: true takes the typed " \
          "word out and only reports the choice (the poetry:composer-menu:choose event).",
          "webmcp: \"name\" lets an in-page agent write the text, send and stop through the composer's own " \
          "gate; leave it off unless the page means an agent to speak for the person.",
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
        option :attachments, :boolean, default: false,
                                       doc: "Files join the message: a paperclip button, a drop on the composer " \
                                            "and a paste into the field, each file a chip above the field."
        option :attachments_name, :string, default: "attachments[]",
                                           doc: "The param key the files arrive under - ending in [] for Rails " \
                                                "params, since a message may carry several."
        option :accept, :string, doc: "The accepted file types, in the native accept grammar (\"image/*,.pdf\"); " \
                                      "other files are refused at intake with a message."
        option :max_size, :integer, doc: "The largest file a message takes, in bytes (10.megabytes)."
        option :max_files, :integer, doc: "The most files one message holds; the surplus is refused with a message."
        option :direct_upload, :boolean, default: false,
                                         doc: "Uploads the files straight to storage through Active Storage's direct " \
                                              "uploads, so the message posts signed ids instead of bytes."
        option :direct_upload_url, :string, doc: "A direct uploads endpoint other than Rails' own (an authenticated " \
                                                 "or scoped route); it turns direct uploads on."
        option :upload, :symbol, default: :on_submit,
                                 doc: "When direct uploads run: :on_submit as the message is sent (Rails' own flow), " \
                                      ":immediate as each file lands, with progress, retry and remove on its chip."
        option :attach_label, :string,
               doc: "The paperclip button's accessible name. Defaults to the locale's \"Attach files\"."

        validates :status, inclusion: { in: STATUSES }
        validates :upload, inclusion: { in: UPLOAD_MODES }

        use_stimulus do
          # A morph puts the server's data-empty back on the root while the
          # field keeps its draft; the controller reads the field again.
          # With attachments: the root is the drop target and the paste
          # target, and the file-input controller keeps the chips. It hears
          # the composer's sent event and drops the files that went.
          on :root do
            behavior :file_drop, accept: :option, multiple: true, max_files: :option, max_size: :option,
                                 paste: true, messages: { from: :rejection_messages }, if: :attachments
            controller :file_input, if: :attachments do
              register
              value :multiple, true
              value :upload, from: :upload_mode
              value :name, from: :attachments_name
              value :url, from: :upload_url
              value :preview, true
              value :messages, from: :upload_messages
              action :files, on: event(:file_drop, :files)
              action :discard, on: event(:composer, :sent)
            end
            # With menus: the controller that opens them, and takes back
            # out the chips that went with an accepted message.
            controller :composer_menu, if: :menus? do
              register
              value :messages, from: :menu_messages
              action :sent, on: event(:composer, :sent)
              action :restore, on: :"turbo:morph-element"
            end
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
          # The menus' keydown is declared first, so it runs first: a key
          # it takes is claimed, and the composer leaves a claimed key
          # alone. That is how Enter chooses an option without sending.
          on :input do
            controller :composer_menu, if: :menus? do
              target :input
              action :keydown, on: :keydown
              action :track, on: %i[input keyup click focus]
              action :blurred, on: :blur
            end
            controller :composer do
              target :input
              action :keydown, on: :keydown
              action :changed, on: :input
            end
          end
          # A press on a menu holds focus in the field; a click chooses.
          on :menu do
            controller :composer_menu do
              target :menu
              action :hold, on: :pointerdown
              action :pick, on: :click
              action :point, on: :pointermove
            end
          end
          # The chips are the client's and the server renders their rows
          # empty: a morph leaves both rows as they are.
          on :references do
            controller :composer_menu do
              target :chips
              action :keep, on: :"turbo:before-morph-element"
            end
          end
          on(:reference_template) { controller(:composer_menu) { target :template } }
          on(:reference_remove) { controller(:composer_menu) { action :remove, on: :click } }
          # The native file input is three controllers' target: the intake
          # lands files in it, the chips mirror it, and the composer reads
          # it to know a message of files alone is not blank.
          on :attachments_control do
            controller(:file_drop) { target :input }
            controller(:file_input) { target :input }
            controller :composer do
              target :attachments
              action :changed, on: :change
            end
          end
          # The paperclip opens the picker without taking focus from the field.
          on :attach do
            controller(:file_drop) { action :open, on: :click }
            controller(:composer) { action :hold_focus, on: :pointerdown }
          end
          on :attachments do
            controller :file_input do
              target :items
              action :keep, on: :"turbo:before-morph-element"
            end
          end
          on(:attachment_template) { controller(:file_input) { target :template } }
          on(:attachment_errors) { controller(:file_input) { target :errors } }
          on(:attachment_remove) { controller(:file_input) { action :remove, on: :click } }
          on(:attachment_retry) { controller(:file_input) { action :retry, on: :click } }
        end

        # The operate surface: what an in-page agent may do to a rendered
        # composer (registered per instance, opt-in - see poetry-agent).
        # Sending posts a message a person cannot take back, so an agent
        # confirms it first.
        tool :set_text,
             description: "Write the message's text into the field, replacing the draft. It does not send.",
             params: { text: { type: "string", required: true, description: "The message text." } },
             executes: %i[composer set_text],
             mutating: true
        tool :send,
             description: "Send the message in the field, as a press of Send would. Nothing goes while the " \
                          "field is blank, a reply is running or a send is on its way; the answer says which.",
             executes: %i[composer send],
             mutating: true,
             consequential: true
        tool :stop,
             description: "Stop the reply that is being written, as a press of Stop would.",
             executes: %i[composer stop],
             mutating: true

        part "composer", "The root - holds the message form and the Stop form; the controller and " \
                         "the emptiness state ride here",
             states: {
               "data-empty" => "the field holds nothing but whitespace and no file is attached " \
                               "(server-set, controller-kept) - the Send button dims",
               "data-populated" => "a file is attached (controller-set, with attachments:)",
               "data-dragging" => "files are dragged over the composer (controller-set) - the field " \
                                  "surface takes the drop tint",
               "data-drag-reject" => "the dragged files would be refused (controller-set) - the tint " \
                                     "turns destructive"
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
        part "composer-attachments", "The chips' row above the field (attachments:) - one Attachment per " \
                                     "file, filled by the controller; hidden while empty",
             states: {
               "data-align" => { condition: "always - the row sits over the field",
                                 values: %w[block-start] }
             }
        part "composer-attachments-control", "The hidden native <input type=file> (dom id " \
                                             "<id>-attachments) - the files' form value; the paperclip " \
                                             "opens its picker"
        part "composer-attachment-template", "The <template> holding one Attachment chip the controller " \
                                             "clones per file"
        part "composer-errors", "The rejections <ul> (role=alert) under the field surface - one line " \
                                "per refused file; hidden until a file is refused"
        part "composer-menu", "One menu's popup over the composer (with_menu) - hidden until the word " \
                              "at the caret starts with its trigger",
             states: {
               "data-open" => "the word at the caret starts with the trigger and an option matches it",
               "data-closed" => "the menu is not showing (server default)",
               "data-trigger" => "always - the character that opens the menu",
               "data-inserts" => { condition: "always - what a choice puts in the message",
                                   values: %w[text chip] },
               "data-at" => { condition: "always - where the trigger opens the menu",
                              values: %w[word start] },
               "data-name" => "name: given - the param key a chip menu's hidden fields post under"
             }
        part "composer-menu-list", "The menu's listbox (dom id <id>-menu-<n>, named by label:) - " \
                                   "holds options only; the field's aria-controls names it"
        part "composer-menu-option", "One option (role=option) - the field's aria-activedescendant " \
                                     "names the highlighted one",
             states: {
               "data-highlighted" => "the option Enter, Tab or a click would choose (controller-set)",
               "data-value" => "always - what the server receives for the choice",
               "data-label" => "always - the option's name, and a chip's text",
               "data-filter-value" => "always - what the typed word is matched against",
               "data-keywords" => "always - the value and any keywords:, matched as well",
               "data-insert" => "insert: given - the exact text a text menu writes",
               "data-run" => "run: true - the choice is only reported"
             }
        part "composer-menu-option-label", "The option's name"
        part "composer-menu-option-description", "Muted text beside the name (description:)"
        part "composer-references", "The chips' row for chosen references (a chip menu) - filled by the " \
                                    "controller, each chip holding its hidden field; hidden while empty",
             states: {
               "data-align" => { condition: "always - the row sits over the field",
                                 values: %w[block-start] }
             }
        part "composer-reference-template", "The <template> holding one reference chip the controller " \
                                            "clones per choice"
        # Send, Stop and the paperclip render as composed Buttons carrying
        # data-slot=composer-send / composer-stop / composer-attach on
        # Button's root - part ownership attributes them to Button, so they
        # are documented here in prose only: Send is the message form's
        # submit button; Stop names the Stop form through its form
        # attribute; the paperclip opens the file picker.

        # Runs the block first, so with_menu's menus are collected before
        # the template reads them; then refuses a status the composer
        # cannot act on, and immediate uploads without an endpoint.
        # @api private
        def before_render
          content
          unless status == :idle || stop_url.present?
            raise ArgumentError, "Composer status: #{status.inspect} needs stop_url: (the Stop button posts there)"
          end
          return unless attachments && upload == :immediate && upload_url.nil?

          raise ArgumentError, "Composer upload: :immediate needs direct_upload: true or direct_upload_url:"
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

        # The message form's attributes with its wiring; files post as multipart.
        # @api private
        def form_attributes
          attrs = { "id" => "#{composer_id}-form" }
          attrs["enctype"] = "multipart/form-data" if attachments
          element_attributes(:form, attrs)
        end

        # The bordered shell wearing InputGroup's chrome, and the drop
        # tint when it takes files.
        # @api private
        def group_attributes
          element_attributes(:group, { "role" => "group",
                                       "class" => InputGroup::Style.css(class: (css(:group) if attachments)) })
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
          if menus?
            # The whole of what a textarea may say about its lists: no
            # role and no expanded state are allowed on it.
            attrs["aria-autocomplete"] = "list"
            attrs["aria-controls"] = menu_models.each_index.map { |index| menu_list_id(index) }.join(" ")
          end
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

        # The chips' row: InputGroup's block-start addon, filled by the controller.
        # @api private
        def attachments_attributes
          group = InputGroup::Style
          element_attributes(:attachments, {
                               "data-slot" => "composer-attachments", "data-align" => "block-start",
                               "class" => group.css(:addon, class: "#{group.css(:addon_block_start)} " \
                                                                   "#{css(:attachments)}")
                             })
        end

        # The hidden native input's attributes. Rails' own submit-time
        # uploads read data-direct-upload-url; in immediate mode the
        # controller owns the uploads, so the input carries none.
        # @api private
        def control_attributes
          attrs = {
            "type" => "file", "hidden" => "", "multiple" => "", "id" => "#{composer_id}-attachments",
            "name" => attachments_name, "accept" => accept, "data-slot" => "composer-attachments-control",
            "data-direct-upload-url" => (upload_url if upload_mode == "on_submit")
          }.compact
          attrs["disabled"] = "" if disabled
          attrs.merge(stimulus_attributes_for(:attachments_control))
        end

        # The paperclip: a ghost Button in InputGroup's in-group chrome.
        # @api private
        def attach_button
          group = InputGroup::Style
          button = Button::Component.new({
            type: :button, variant: :ghost, disabled: disabled,
            label: attach_label.presence || t("poetry.composer.attach"),
            class: group.css(:button, class: group.css(:button_icon_sm)),
            "data-slot" => "composer-attach", "data-size" => "icon-sm"
          }.merge(stimulus_attributes_for(:attach)))

          render(button) { render(Icon::Component.new(name: :paperclip)) }
        end

        # The chip template's attributes.
        # @api private
        def template_attributes
          { "data-slot" => "composer-attachment-template" }.merge(stimulus_attributes_for(:attachment_template))
        end

        # A chip action's data: the wiring's action string plus the role
        # the file-input controller reads to show or hide it.
        # @api private
        def chip_action_data(element, role)
          { action: stimulus_attributes_for(element)["data-action"], upload_action: role }
        end

        # The controller-filled rejections list's attributes (role=alert,
        # hidden until a file is refused).
        # @api private
        def errors_attributes
          { "data-slot" => "composer-errors", "role" => "alert", "hidden" => "", "class" => css(:errors) }
            .merge(stimulus_attributes_for(:attachment_errors))
        end

        private :form_attributes, :group_attributes, :input_attributes, :footer_attributes, :action,
                :stop_form_attributes, :attachments_attributes, :control_attributes, :attach_button,
                :template_attributes, :chip_action_data, :errors_attributes
      end
    end
  end
end
