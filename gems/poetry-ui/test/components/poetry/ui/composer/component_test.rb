# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Composer
      class ComponentTest < ViewComponent::TestCase
        IDENTIFIER = "poetry--core--composer"

        def render_composer(**, &)
          Nokogiri::HTML5.fragment(
            render_inline(Component.new(id: "composer", url: "/chats/1/messages", **), &).to_html
          )
        end

        def render_erb(erb)
          ApplicationController.renderer.render(inline: erb, layout: false)
        end

        def slot(fragment, name) = fragment.at_css(%([data-slot="#{name}"]))

        def test_renders_the_contract_surface
          composer = render_composer(stop_url: "/chats/1/stop")
          root = slot(composer, "composer")

          assert_equal "composer", root["data-component"]
          assert_equal IDENTIFIER, root["data-controller"]
          assert_equal "turbo:morph-element->#{IDENTIFIER}#changed", root["data-action"]
          assert_equal "composer", root["id"]
          assert_equal "composer-form", slot(composer, "composer-form")["id"]
          assert_equal "composer-input", slot(composer, "input-group-control")["id"]
          assert_equal "composer-action", slot(composer, "composer-action")["id"]
          assert_equal "composer-stop", slot(composer, "composer-stop-form")["id"]
          assert slot(composer, "composer-group"), "the bordered shell"
          assert_equal "block-end", slot(composer, "input-group-addon")["data-align"]
        end

        def test_the_message_form_posts_to_the_url_and_carries_the_gate
          form = slot(render_composer, "composer-form")

          assert_equal "form", form.name
          assert_equal "/chats/1/messages", form["action"]
          assert_equal "post", form["method"]
          assert_equal "form", form["data-#{IDENTIFIER}-target"]
          assert_equal "submit->#{IDENTIFIER}#guard turbo:submit-end->#{IDENTIFIER}#settle", form["data-action"]
        end

        def test_the_field_is_a_named_textarea_wired_for_the_keys
          field = slot(render_composer(name: "content", placeholder: "Ask anything"), "input-group-control")

          assert_equal "textarea", field.name
          assert_equal "content", field["name"]
          assert_equal "Ask anything", field["placeholder"]
          assert_equal "1", field["rows"]
          assert_equal "Message", field["aria-label"]
          assert_equal "send", field["enterkeyhint"]
          assert_equal "input", field["data-#{IDENTIFIER}-target"]
          assert_equal "keydown->#{IDENTIFIER}#keydown input->#{IDENTIFIER}#changed", field["data-action"]
        end

        def test_the_param_defaults_to_message
          assert_equal "message", slot(render_composer, "input-group-control")["name"]
        end

        def test_the_field_opens_at_one_row_and_stops_growing_at_the_ceiling
          classes = slot(render_composer, "input-group-control")["class"].split

          # Textarea's own floor is four rows tall; the composer's wins, once.
          assert_includes classes, "min-h-10"
          refute_includes classes, "min-h-16"
          assert_includes classes, "max-h-48"
          assert_includes classes, "field-sizing-content"
          assert_includes classes, "cn-input-group-textarea"
        end

        def test_input_class_moves_the_floor_and_the_ceiling
          classes = slot(render_composer(input_class: "min-h-24 max-h-80"), "input-group-control")["class"].split

          assert_includes classes, "min-h-24"
          assert_includes classes, "max-h-80"
          refute_includes classes, "min-h-10"
          refute_includes classes, "max-h-48"
        end

        def test_idle_renders_send_as_the_message_forms_own_button
          composer = render_composer(stop_url: "/chats/1/stop")
          action = slot(composer, "composer-action")
          send_button = slot(composer, "composer-send")

          assert_nil action["data-running"]
          assert_nil action["data-stopping"]
          assert_nil action["data-version"]
          assert_equal "submit", send_button["type"]
          assert_nil send_button["form"], "Send belongs to the form it sits in"
          assert_equal "Send message", send_button["aria-label"]
          assert_equal "send", send_button["data-#{IDENTIFIER}-target"]
          assert_equal "pointerdown->#{IDENTIFIER}#holdFocus", send_button["data-action"]
          assert_equal "composer-form", send_button.ancestors("form").first["id"]
          assert_nil slot(composer, "composer-stop")
        end

        def test_running_renders_stop_bound_to_the_stop_form
          composer = render_composer(status: :running, stop_url: "/chats/1/stop")
          action = slot(composer, "composer-action")
          stop = slot(composer, "composer-stop")
          stop_form = slot(composer, "composer-stop-form")

          assert_equal "", action["data-running"]
          assert_nil action["data-stopping"]
          assert_equal "submit", stop["type"]
          assert_equal "composer-stop", stop["form"]
          assert_equal "Stop", stop["aria-label"]
          assert_equal "stop", stop["data-#{IDENTIFIER}-target"]
          assert_equal "pointerdown->#{IDENTIFIER}#holdFocus click->#{IDENTIFIER}#returnFocus", stop["data-action"]
          assert_nil stop["disabled"]
          assert_nil slot(composer, "composer-send"), "a Stop button on the page is the running state"

          assert_equal "form", stop_form.name
          assert_equal "/chats/1/stop", stop_form["action"]
          assert_equal "post", stop_form["method"]
          assert stop_form.key?("hidden")
        end

        def test_the_stop_form_is_a_sibling_so_stopping_never_sends_the_draft
          composer = render_composer(status: :running, stop_url: "/chats/1/stop", value: "a draft")
          stop_form = slot(composer, "composer-stop-form")

          assert_empty stop_form.ancestors("form"), "a form inside a form is not a form"
          assert_empty stop_form.css("textarea")
          assert_equal slot(composer, "composer"), stop_form.parent
        end

        def test_each_form_carries_its_own_forgery_token
          composer = render_composer(status: :running, stop_url: "/chats/1/stop")
          tokens = %w[composer-form composer-stop-form].map do |name|
            slot(composer, name).at_css('input[name="authenticity_token"]')&.[]("value")
          end

          assert tokens.all?(&:present?), "both forms post on their own"
          refute_equal tokens.first, tokens.last
        end

        def test_stopping_holds_the_stop_button_busy_and_disabled
          composer = render_composer(status: :stopping, stop_url: "/chats/1/stop")
          action = slot(composer, "composer-action")
          stop = slot(composer, "composer-stop")

          assert_equal "", action["data-running"]
          assert_equal "", action["data-stopping"]
          assert stop.key?("disabled")
          assert_equal "true", stop["aria-busy"]
          assert_equal "stop", stop["data-#{IDENTIFIER}-target"], "still the running state for the controller"
          assert stop.at_css('[data-slot="spinner"]')
        end

        def test_a_status_other_than_idle_needs_somewhere_to_stop
          error = assert_raises(ArgumentError) { render_composer(status: :running) }

          assert_match(/needs stop_url:/, error.message)
        end

        def test_an_unknown_status_is_refused
          assert_raises(ArgumentError) { render_composer(status: :thinking, stop_url: "/stop") }
        end

        def test_no_stop_form_without_a_stop_url
          assert_nil slot(render_composer, "composer-stop-form")
        end

        def test_version_stamps_the_slot_for_a_versioned_replace
          action = slot(render_composer(version: 7), "composer-action")

          assert_equal "7", action["data-version"]
        end

        def test_emptiness_is_server_rendered_from_the_draft
          assert_equal "", slot(render_composer, "composer")["data-empty"]
          assert_equal "", slot(render_composer(value: "  \n "), "composer")["data-empty"]
          assert_nil slot(render_composer(value: "a draft"), "composer")["data-empty"]
        end

        def test_a_draft_renders_as_escaped_content
          composer = render_composer(value: "</textarea><script>alert(1)</script>")

          assert_equal "</textarea><script>alert(1)</script>", slot(composer, "input-group-control").text
          assert_empty composer.css("script")
        end

        def test_enter_can_be_a_line_break
          composer = render_composer(submit_on_enter: false)

          assert_equal "false", slot(composer, "composer")["data-#{IDENTIFIER}-submit-on-enter-value"]
          assert_equal "enter", slot(composer, "input-group-control")["enterkeyhint"]
        end

        def test_disabled_closes_the_field_and_the_send_button
          composer = render_composer(disabled: true)

          assert slot(composer, "input-group-control").key?("disabled")
          assert slot(composer, "composer-send").key?("disabled")
        end

        def test_accessible_names_can_be_given
          composer = render_composer(label: "Ask the analyst", send_label: "Ask")
          running = render_composer(status: :running, stop_url: "/stop", stop_label: "Stop the answer")

          assert_equal "Ask the analyst", slot(composer, "input-group-control")["aria-label"]
          assert_equal "Ask", slot(composer, "composer-send")["aria-label"]
          assert_equal "Stop the answer", slot(running, "composer-stop")["aria-label"]
        end

        def test_block_content_is_the_tools_row_ahead_of_the_action
          composer = render_composer { '<button type="button" id="attach">Attach</button>'.html_safe }
          footer = slot(composer, "input-group-addon")

          assert_equal(%w[attach composer-action], footer.element_children.map { |child| child["id"] })
        end

        def test_the_send_button_dims_while_the_field_is_empty
          assert_includes slot(render_composer, "composer-send")["class"], "group-data-[empty]/composer:opacity-50"
          assert_includes slot(render_composer, "composer")["class"], "group/composer"
        end

        def test_the_caller_class_lands_on_the_root
          root = slot(render_composer(class: "max-w-xl"), "composer")

          assert_includes root["class"].split, "max-w-xl"
          assert_includes root["class"].split, "w-full"
        end

        def test_the_id_is_reduced_to_a_safe_token
          composer = Nokogiri::HTML5.fragment(
            render_inline(Component.new(id: 'chat"><script>', url: "/messages")).to_html
          )

          assert_equal "chatscript", slot(composer, "composer")["id"]
          assert_equal "chatscript-action", slot(composer, "composer-action")["id"]
          assert_raises(ArgumentError) { render_inline(Component.new(id: '"><', url: "/messages")) }
        end

        FILE_DROP = "poetry--core--file-drop"
        FILE_INPUT = "poetry--core--file-input"

        def test_without_attachments_nothing_of_them_renders
          composer = render_composer
          html = composer.to_html

          assert_nil slot(composer, "composer-form")["enctype"]
          assert_nil slot(composer, "composer-attach")
          assert_nil composer.at_css("input[type=file]")
          assert_nil composer.at_css("template")
          refute_includes html, FILE_DROP
          refute_includes html, FILE_INPUT
          refute_includes slot(composer, "composer-group")["class"], "dragging"
        end

        def test_attachments_put_the_intake_and_the_chips_on_the_root
          composer = render_composer(attachments: true, accept: "image/*,.pdf", max_files: 4, max_size: 2048)
          root = slot(composer, "composer")

          assert_equal "#{FILE_DROP} #{FILE_INPUT} #{IDENTIFIER}", root["data-controller"]
          assert_equal "image/*,.pdf", root["data-#{FILE_DROP}-accept-value"]
          assert_equal "true", root["data-#{FILE_DROP}-multiple-value"]
          assert_equal "4", root["data-#{FILE_DROP}-max-files-value"]
          assert_equal "2048", root["data-#{FILE_DROP}-max-size-value"]
          assert_equal "true", root["data-#{FILE_DROP}-paste-value"]
          assert_equal FileInput::Component::REJECTION_CODES.values.sort,
                       JSON.parse(root["data-#{FILE_DROP}-messages-value"]).keys.sort
          assert_equal "none", root["data-#{FILE_INPUT}-upload-value"]
          assert_equal "attachments[]", root["data-#{FILE_INPUT}-name-value"]
          assert_equal "true", root["data-#{FILE_INPUT}-preview-value"]
          assert_equal "poetry:file-drop:files->#{FILE_INPUT}#files poetry:composer:sent->#{FILE_INPUT}#discard " \
                       "turbo:morph-element->#{IDENTIFIER}#changed", root["data-action"]
        end

        def test_the_native_file_input_is_hidden_in_the_message_form_and_three_controllers_target_it
          composer = render_composer(attachments: true, accept: "image/*", attachments_name: "message[files][]")
          form = slot(composer, "composer-form")
          control = form.at_css("input[type=file]")

          assert_equal "multipart/form-data", form["enctype"]
          assert_equal "composer-attachments", control["id"]
          assert_equal "message[files][]", control["name"]
          assert_equal "image/*", control["accept"]
          assert control.key?("hidden"), "the paperclip is the visible control"
          assert control.key?("multiple")
          assert_equal "input", control["data-#{FILE_DROP}-target"]
          assert_equal "input", control["data-#{FILE_INPUT}-target"]
          assert_equal "attachments", control["data-#{IDENTIFIER}-target"]
          assert_equal "change->#{IDENTIFIER}#changed", control["data-action"]
          assert_nil control["data-direct-upload-url"]
        end

        def test_the_paperclip_opens_the_picker_and_never_submits_or_takes_focus
          composer = render_composer(attachments: true) { "<span id=\"tool\"></span>".html_safe }
          attach = slot(composer, "composer-attach")
          footer = slot(composer, "input-group-addon")

          assert_equal "button", attach["type"]
          assert_equal "Attach files", attach["aria-label"]
          assert_equal "click->#{FILE_DROP}#open pointerdown->#{IDENTIFIER}#holdFocus", attach["data-action"]
          leading = footer.element_children.first(2).map { |child| child["data-slot"] }

          assert_equal %w[composer-attachments-control composer-attach], leading
          assert_equal "tool", footer.element_children[2]["id"]
          assert_equal "Add a file", slot(render_composer(attachments: true, attach_label: "Add a file"),
                                          "composer-attach")["aria-label"]
        end

        def test_the_chips_row_leads_the_field_surface_and_starts_empty
          composer = render_composer(attachments: true)
          group = slot(composer, "composer-group")
          row = slot(composer, "composer-attachments")

          assert_equal row, group.element_children.first
          assert_equal "block-start", row["data-align"]
          assert_equal "items", row["data-#{FILE_INPUT}-target"]
          assert_equal "turbo:before-morph-element->#{FILE_INPUT}#keep", row["data-action"], "a morph leaves the chips"
          assert_empty row.children, "an empty row hides itself (empty:hidden)"
          assert_includes row["class"], "empty:hidden"
          assert_includes group["class"], "group-data-[dragging]/composer:border-primary"
        end

        def test_the_chip_template_carries_the_seats_the_controller_fills
          composer = render_composer(attachments: true)
          template = slot(composer, "composer-attachment-template")
          chip = Nokogiri::HTML5.fragment(template.inner_html).at_css("[data-slot=attachment]")

          assert_equal "template", template["data-#{FILE_INPUT}-target"]
          assert_equal "sm", chip["data-size"]
          seats = %w[attachment-media attachment-title attachment-description attachment-progress]

          present = seats.select { |seat| chip.at_css("[data-slot=#{seat}]") }

          assert_equal seats, present
          remove = chip.at_css("[data-upload-action=remove]")
          retry_button = chip.at_css("[data-upload-action=retry]")

          assert_equal "click->#{FILE_INPUT}#remove", remove["data-action"]
          assert_equal "Remove", remove["aria-label"]
          assert_equal "click->#{FILE_INPUT}#retry", retry_button["data-action"]
          assert retry_button.key?("hidden")
        end

        def test_the_rejections_follow_the_field_surface_as_an_alert
          composer = render_composer(attachments: true)
          errors = slot(composer, "composer-errors")

          assert_equal "ul", errors.name
          assert_equal "alert", errors["role"]
          assert errors.key?("hidden")
          assert_equal "errors", errors["data-#{FILE_INPUT}-target"]
          assert_equal slot(composer, "composer-form"), errors.parent
          assert_equal slot(composer, "composer-group"), errors.previous_element
        end

        def test_direct_uploads_follow_the_upload_mode
          on_submit = render_composer(attachments: true, direct_upload_url: "/uploads")
          immediate = render_composer(attachments: true, direct_upload_url: "/uploads", upload: :immediate)

          assert_equal "on_submit", slot(on_submit, "composer")["data-#{FILE_INPUT}-upload-value"]
          assert_equal "/uploads", on_submit.at_css("input[type=file]")["data-direct-upload-url"]
          assert_equal "immediate", slot(immediate, "composer")["data-#{FILE_INPUT}-upload-value"]
          assert_equal "/uploads", slot(immediate, "composer")["data-#{FILE_INPUT}-url-value"]
          assert_nil immediate.at_css("input[type=file]")["data-direct-upload-url"]
        end

        def test_immediate_uploads_need_an_endpoint_and_the_mode_is_closed
          error = assert_raises(ArgumentError) { render_composer(attachments: true, upload: :immediate) }

          assert_match "Composer upload: :immediate needs direct_upload: true or direct_upload_url:", error.message
          assert_raises(ArgumentError) { render_composer(attachments: true, upload: :later) }
        end

        def test_a_disabled_composer_takes_no_files
          composer = render_composer(attachments: true, disabled: true)

          assert composer.at_css("input[type=file]").key?("disabled")
          assert slot(composer, "composer-attach").key?("disabled")
        end

        MENU = "poetry--core--composer-menu"

        def render_with_menus(**)
          render_composer(**) do |composer|
            composer.with_menu(trigger: "@", label: "People", icon: :user) do |menu|
              menu.with_item(value: "ana", label: "Ana <Diaz>", description: "Design", keywords: %w[ux research])
              menu.with_item(value: "jordan")
            end
            composer.with_menu(trigger: "/", label: "Commands", at: :start) do |menu|
              menu.with_item(label: "summarize", insert: "/summarize ")
              menu.with_item(label: "clear", run: true)
            end
            composer.with_menu(trigger: "#", label: "Files", inserts: :chip, name: "context[]") do |menu|
              menu.with_item(value: "doc_1", label: "Q3 plan.pdf", icon: :file)
            end
            "<span id=\"tool\"></span>".html_safe
          end
        end

        def test_without_menus_nothing_of_them_renders
          composer = render_composer
          field = slot(composer, "input-group-control")

          assert_nil slot(composer, "composer-menu")
          assert_nil slot(composer, "composer-references")
          assert_nil field["aria-autocomplete"]
          assert_nil field["aria-controls"]
          refute_includes composer.to_html, MENU
        end

        def test_menus_put_their_controller_on_the_root_ahead_of_the_composers
          root = slot(render_with_menus, "composer")

          assert_equal "#{MENU} #{IDENTIFIER}", root["data-controller"]
          assert_equal "poetry:composer:sent->#{MENU}#sent turbo:morph-element->#{MENU}#restore " \
                       "turbo:morph-element->#{IDENTIFIER}#changed", root["data-action"]
          messages = JSON.parse(root["data-#{MENU}-messages-value"])

          assert_equal %w[added one other removed], messages.keys.sort
          assert_equal "{count} suggestions", messages["other"]
        end

        def test_the_field_says_what_a_textarea_may_and_the_menus_keydown_runs_first
          composer = render_with_menus
          field = slot(composer, "input-group-control")

          assert_equal "textarea", field.name
          assert_equal "list", field["aria-autocomplete"]
          assert_equal "composer-menu-0 composer-menu-1 composer-menu-2", field["aria-controls"]
          assert_nil field["role"]
          assert_nil field["aria-expanded"]
          assert_nil field["aria-activedescendant"]
          assert_equal "input", field["data-#{MENU}-target"]
          assert_equal "keydown->#{MENU}#keydown input->#{MENU}#track keyup->#{MENU}#track click->#{MENU}#track " \
                       "focus->#{MENU}#track blur->#{MENU}#blurred keydown->#{IDENTIFIER}#keydown " \
                       "input->#{IDENTIFIER}#changed", field["data-action"]
        end

        def test_each_menu_is_a_closed_popup_outside_the_form_with_what_a_choice_needs
          composer = render_with_menus
          menus = composer.css("[data-slot=composer-menu]")
          people, commands, files = menus.to_a

          assert_equal 3, menus.size
          assert(menus.all? { |menu| menu.key?("hidden") && menu.key?("data-closed") && menu.ancestors("form").empty? })
          assert_equal %w[@ / #], menus.pluck("data-trigger")
          assert_equal %w[text text chip], menus.pluck("data-inserts")
          assert_equal %w[word start word], menus.pluck("data-at")
          assert_nil people["data-name"]
          assert_equal "context[]", files["data-name"]
          assert_equal "menu", commands["data-#{MENU}-target"]
          assert_equal "pointerdown->#{MENU}#hold click->#{MENU}#pick pointermove->#{MENU}#point " \
                       "turbo:frame-load->#{MENU}#loaded turbo:before-fetch-response->#{MENU}#answered " \
                       "turbo:frame-missing->#{MENU}#failed turbo:fetch-request-error->#{MENU}#failed",
                       people["data-action"]
          assert(menus.none? { |menu| menu.key?("data-src") || menu.key?("data-param") })
        end

        def render_with_a_server_menu(param: "q", &)
          render_composer do |composer|
            composer.with_menu(trigger: "@", label: "People", icon: :user, src: "/people/mentions?team=7",
                               param: param, &)
            composer.with_menu(trigger: "/", label: "Commands", at: :start) do |menu|
              menu.with_item(label: "summarize")
            end
          end
        end

        def test_a_server_fed_menu_names_its_address_and_its_listbox_is_a_turbo_frame
          composer = render_with_a_server_menu
          people, commands = composer.css("[data-slot=composer-menu]").to_a
          list = people.at_css("[role=listbox]")

          assert_equal "/people/mentions?team=7", people["data-src"]
          assert_equal "q", people["data-param"]
          assert_equal "turbo-frame", list.name
          assert_equal "composer-menu-0", list["id"]
          assert_equal "People", list["aria-label"]
          assert_includes list["class"].split, "block", "a frame is an inline box until told otherwise"
          assert_empty list.element_children
          refute list.key?("data-query"), "nothing rendered answers no word yet"
          refute list.key?("src"), "the controller points the frame; the page never fetches at load"
          assert_equal "div", commands.at_css("[role=listbox]").name
          refute commands.key?("data-src")
          assert_equal "composer-menu-0 composer-menu-1", composer.at_css("textarea")["aria-controls"]
        end

        def test_options_rendered_in_a_server_fed_menu_answer_the_bare_trigger
          composer = render_with_a_server_menu { |menu| menu.with_item(value: "ana", label: "Ana Diaz") }
          list = composer.at_css("#composer-menu-0")

          assert_equal "", list["data-query"]
          assert_equal %w[composer-menu-0-option-0], list.element_children.pluck("id")
          assert list.at_css("[role=option] svg"), "the menu's icon leads the option"
        end

        def test_a_server_fed_menu_needs_a_query_key
          menu = render_with_a_server_menu(param: "term").at_css("[data-slot=composer-menu]")

          assert_equal "term", menu["data-param"]

          ["", "two words"].each do |param|
            error = assert_raises(ArgumentError) { render_with_a_server_menu(param: param) }

            assert_match(/param:/, error.message)
          end
        end

        # frame: is the Turbo-Frame header the request carries; nil is a
        # request no frame made (the test request outlives one render).
        def answer(frame: nil, **, &)
          vc_test_request.headers["Turbo-Frame"] = frame
          Nokogiri::HTML5.fragment(render_inline(MenuOptions.new(**), &).to_html)
        end

        def test_the_answer_is_the_frame_that_asked_with_the_options_a_menu_renders
          frame = answer(frame: "composer-menu-0", icon: :user) do |menu|
            menu.with_item(value: "ana", label: "Ana <Diaz>", description: "Design", keywords: %w[ux])
            menu.with_item(value: "jordan", icon: :star)
          end.at_css("turbo-frame")
          ana, jordan = frame.element_children.to_a
          page = render_composer do |composer|
            composer.with_menu(trigger: "@", label: "People", icon: :user) do |menu|
              menu.with_item(value: "ana", label: "Ana <Diaz>", description: "Design", keywords: %w[ux])
            end
          end.at_css("#composer-menu-0-option-0")

          assert_equal "composer-menu-0", frame["id"]
          assert_equal %w[id], frame.keys, "the page's frame keeps its role, its name and its classes"
          assert_equal %w[composer-menu-0-option-0 composer-menu-0-option-1], [ana["id"], jordan["id"]]
          assert_equal page.to_html, ana.to_html, "an answered option is the option the page renders"
          assert_equal "Ana <Diaz>", ana.at_css("[data-slot=composer-menu-option-label]").text
          assert_equal "jordan", jordan["data-label"]
          assert jordan.at_css("svg"), "an item's own icon"
        end

        def test_the_answer_takes_an_id_and_falls_back_when_no_frame_asked
          named = answer(id: "inbox-menu-2", frame: "composer-menu-0") do |menu|
            menu.with_item(value: "ana")
          end
          alone = answer { |menu| menu.with_item(value: "ana") }

          assert_equal "inbox-menu-2", named.at_css("turbo-frame")["id"]
          assert_equal "inbox-menu-2-option-0", named.at_css("[role=option]")["id"]
          assert_equal MenuOptions::FALLBACK_ID, alone.at_css("turbo-frame")["id"]
        end

        def test_an_answer_with_no_matches_is_an_empty_frame_and_an_item_needs_a_value_or_a_label
          frame = answer(frame: "composer-menu-0").at_css("turbo-frame")

          assert_empty frame.element_children
          assert_raises(ArgumentError) { answer { |menu| menu.with_item(description: "nobody") } }
        end

        def test_the_answer_helper_renders_the_frame
          html = render_erb(<<~ERB)
            <%= poetry_composer_menu_options(id: "composer-menu-0", icon: :user) do |menu| %>
              <% menu.with_item(value: "ana", label: "Ana Diaz") %>
            <% end %>
          ERB
          frame = Nokogiri::HTML5.fragment(html).at_css("turbo-frame#composer-menu-0")

          assert_equal %w[ana], frame.css("[role=option]").pluck("data-value")
        end

        def test_a_menus_listbox_is_named_and_holds_options_only
          composer = render_with_menus
          list = composer.at_css("#composer-menu-0")

          assert_equal "listbox", list["role"]
          assert_equal "People", list["aria-label"]
          assert_equal %w[option option], list.element_children.pluck("role")
          assert_equal %w[composer-menu-0-option-0 composer-menu-0-option-1], list.element_children.pluck("id")
          assert_equal %w[false false], list.element_children.pluck("aria-selected")
        end

        def test_an_option_carries_its_value_its_label_and_what_filtering_matches
          composer = render_with_menus
          ana, jordan = composer.css("#composer-menu-0 [role=option]").to_a

          assert_equal "ana", ana["data-value"]
          assert_equal "Ana <Diaz>", ana["data-label"]
          assert_equal "Ana <Diaz>", ana["data-filter-value"]
          assert_equal "ana ux research", ana["data-keywords"]
          assert_equal "Ana <Diaz>", ana.at_css("[data-slot=composer-menu-option-label]").text
          assert_equal "Design", ana.at_css("[data-slot=composer-menu-option-description]").text
          assert ana.at_css("svg"), "the menu's icon leads each option"
          assert_equal "jordan", jordan["data-label"], "the label defaults to the value"
          assert_nil jordan.at_css("[data-slot=composer-menu-option-description]")
          assert_nil ana["data-insert"]
          refute ana.key?("data-run")
        end

        def test_a_commands_text_and_its_run_mark_ride_the_option
          composer = render_with_menus
          summarize, clear = composer.css("#composer-menu-1 [role=option]").to_a

          assert_equal "/summarize ", summarize["data-insert"]
          assert_equal "summarize", summarize["data-value"], "the value defaults to the label"
          assert clear.key?("data-run")
          assert_nil summarize.at_css("svg"), "no icon unless the menu or the item names one"
        end

        def test_a_chip_menu_adds_the_references_row_and_its_template
          composer = render_with_menus
          row = slot(composer, "composer-references")
          template = slot(composer, "composer-reference-template")
          chip = Nokogiri::HTML5.fragment(template.inner_html).at_css("[data-slot=attachment]")

          assert_equal slot(composer, "composer-group"), row.parent
          assert_equal "block-start", row["data-align"]
          assert_equal "chips", row["data-#{MENU}-target"]
          assert_equal "turbo:before-morph-element->#{MENU}#keep", row["data-action"], "a morph leaves the chips"
          assert_empty row.children
          assert_equal "template", template["data-#{MENU}-target"]
          assert chip.at_css("[data-slot=attachment-title]")
          assert_equal "click->#{MENU}#remove", chip.at_css("button")["data-action"]
          assert_equal "Remove", chip.at_css("button")["aria-label"]
        end

        def test_text_menus_alone_render_no_references_row
          composer = render_composer do |builder|
            builder.with_menu(trigger: "@", label: "People") { |menu| menu.with_item(value: "ana") }
            nil
          end

          assert slot(composer, "composer-menu")
          assert_nil slot(composer, "composer-references")
          assert_nil slot(composer, "composer-reference-template")
        end

        def test_the_tools_row_keeps_the_blocks_content_beside_the_menus
          composer = render_with_menus

          assert slot(composer, "input-group-addon").at_css("#tool")
          assert_nil composer.at_css("[data-slot=composer-menu] #tool")
        end

        def test_a_menu_the_controller_could_not_act_on_is_refused
          refusals = {
            "must be one or more characters" => { trigger: " ", label: "People" },
            "accessible name" => { trigger: "@", label: "" },
            "inserts: must be one of" => { trigger: "@", label: "People", inserts: :token },
            "at: must be one of" => { trigger: "@", label: "People", at: :line },
            "needs name:" => { trigger: "#", label: "Files", inserts: :chip }
          }
          refusals.each do |message, options|
            error = assert_raises(ArgumentError) { render_composer { |composer| composer.with_menu(**options) } }
            assert_match message, error.message
          end
        end

        def test_two_menus_cannot_share_a_trigger_and_an_item_needs_a_value_or_a_label
          taken = assert_raises(ArgumentError) do
            render_composer do |composer|
              composer.with_menu(trigger: "@", label: "People")
              composer.with_menu(trigger: "@", label: "Teams")
            end
          end
          nameless = assert_raises(ArgumentError) do
            render_composer { |composer| composer.with_menu(trigger: "@", label: "People", &:with_item) }
          end

          assert_match "already taken", taken.message
          assert_match "needs value: or label:", nameless.message
        end

        def test_the_tools_an_agent_may_call_are_declared_with_their_safety
          tools = Component.tool_definitions.index_by { |tool| tool["name"] }

          assert_equal %w[send set_text stop], tools.keys.sort
          assert_equal "#{IDENTIFIER}#setText", tools["set_text"]["executes"]
          assert_equal "#{IDENTIFIER}#send", tools["send"]["executes"]
          assert_equal "#{IDENTIFIER}#stop", tools["stop"]["executes"]
          assert_equal %w[text], tools["set_text"].dig("inputSchema", "required")
          assert(tools.values.none? { |tool| tool.dig("annotations", "readOnlyHint") })
          assert tools["send"].dig("annotations", "consequentialHint"), "an agent confirms a send"
          refute tools["stop"].dig("annotations", "consequentialHint")
        end

        def test_a_composer_exposes_its_tools_only_when_asked
          with_registrar_manifest do
            registrar = Poetry::Core::Concerns::AgentTools::WEBMCP_CONTROLLER

            refute_includes render_composer.to_html, registrar

            root = slot(render_composer(webmcp: "chat", stop_url: "/chats/1/stop"), "composer")
            tools = JSON.parse(root["data-#{registrar}-tools-value"])

            assert_includes root["data-controller"].split, registrar
            assert_equal "chat", root["data-#{registrar}-name-value"]
            assert_equal %w[send set_text stop], tools.pluck("name").sort
          end
        end

        # The registrar is poetry-agent's controller; its manifest entry
        # stands in here so the attribute builder accepts its names.
        def with_registrar_manifest
          catalog = Poetry::Core::Stimulus::Manifest.catalog
          registrar = Poetry::Core::Concerns::AgentTools::WEBMCP_CONTROLLER
          had = catalog.key?(registrar)
          catalog[registrar] ||= {
            "targets" => [],
            "values" => { "name" => { "type" => "String" }, "tools" => { "type" => "Array" },
                          "budget" => { "type" => "Number", "default" => 20 } },
            "classes" => [], "methods" => %w[connect disconnect register unregister], "events" => []
          }
          yield
        ensure
          catalog.delete(registrar) unless had
        end

        def test_the_helper_renders_the_slot_the_composer_renders
          %i[idle running stopping].each do |status|
            inside = slot(render_composer(status: status, stop_url: "/stop", version: 3), "composer-action").to_html
            alone = Nokogiri::HTML5.fragment(
              render_erb(%(<%= poetry_composer_action(id: "composer", status: :#{status}, version: 3) %>))
            ).at_css('[data-slot="composer-action"]').to_html

            assert_equal inside, alone, "status #{status}: a redraw must be the element the page rendered"
          end
        end

        def test_the_helper_refuses_an_unknown_status
          assert_raises(ActionView::Template::Error, ArgumentError) do
            render_erb(%(<%= poetry_composer_action(id: "composer", status: :thinking) %>))
          end
        end

        def test_the_composer_helper_takes_the_tools_block
          html = render_erb(<<~ERB)
            <%= poetry_composer(id: "composer", url: "/messages") do %>
              <%= poetry_input_group_text { "Shift+Enter for a new line" } %>
            <% end %>
          ERB

          assert_includes html, 'data-component="composer"'
          assert_includes html, "Shift+Enter for a new line"
        end
      end
    end
  end
end
