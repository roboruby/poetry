# frozen_string_literal: true

require "json"
require "nokogiri"

module Poetry
  module Eval
    # The eval harness: five frozen task pairs covering the
    # full 10-component catalog, each rendered per arm and scored by
    # deterministic gates. Arms are FROZEN representative generations
    # (realistic, never strawmen) so the eval runs without burning tokens
    # (the hifumi lesson); thesis-level receipts accrue as the skill and
    # live generation land.
    #
    # The scorer-portability rule (the A/B honesty split): CROSS_ARM gates
    # run identically on every arm and are the only comparable numbers;
    # POETRY_ONLY gates cannot structurally fail a non-poetry artifact and
    # are reported as diagnostics, never as comparisons.
    class Runner
      INTERACTIVE_TAGS = %w[button a].freeze

      Gate = Struct.new(:name, :scope, :check) do
        def run(doc, html)
          [name, check.call(doc, html)]
        end
      end

      # Gates every arm of every task faces (checkable on ANY html).
      UNIVERSAL = [
        Gate.new(:no_raw_colors, :cross_arm, lambda { |_doc, html|
          # The cheapest slop-detector rule: arbitrary color values
          # bypass the theme.
          !html.match?(/\b(?:bg|text|border|ring|stroke|fill)-\[(?:#|rgb|hsl|oklch)/)
        })
      ].freeze

      TASKS = {
        "button" => {
          "description" => "A destructive 'Delete account' button with a leading trash icon",
          "gates" => [
            Gate.new(:renders, :cross_arm, ->(doc, _html) { doc.css("button, [role=button]").any? }),
            Gate.new(:accessible_name, :cross_arm, lambda { |doc, _html|
              control = doc.css("button, [role=button]").first
              control && (control.text.strip.length.positive? || control["aria-label"].to_s.strip.length.positive?)
            }),
            Gate.new(:explicit_type, :cross_arm, lambda { |doc, _html|
              types = %w[button submit reset]
              doc.css("button").all? { |button| types.include?(button["type"]) }
            }),
            Gate.new(:focus_visible_treatment, :cross_arm, ->(_doc, html) { html.include?("focus-visible:") })
          ]
        },
        "dialog" => {
          "description" => "A settings dialog opened by a button, with a description and a confirm action",
          "gates" => [
            Gate.new(:modal_semantics, :cross_arm, ->(doc, _html) { doc.css("dialog, [role=dialog]").any? }),
            Gate.new(:labelled_overlay, :cross_arm, lambda { |doc, _html|
              overlay = doc.css("dialog, [role=dialog]").first
              !overlay.nil? && !(overlay["aria-labelledby"] || overlay["aria-label"]).nil?
            }),
            Gate.new(:trigger_present, :cross_arm, ->(doc, _html) { doc.css("button").any? }),
            Gate.new(:focus_visible_treatment, :cross_arm, ->(_doc, html) { html.include?("focus-visible:") })
          ]
        },
        "form_field" => {
          "description" => "An email field labeled 'Work email', required, with a hint and the error 'can't be blank'",
          "gates" => [
            Gate.new(:label_wired, :cross_arm, lambda { |doc, _html|
              input = doc.css("input").first
              !input.nil? && (doc.css(%(label[for="#{input["id"]}"])).any? || !input["aria-label"].nil?)
            }),
            Gate.new(:error_associated, :cross_arm, lambda { |doc, _html|
              input = doc.css("input").first
              ids = input ? input["aria-describedby"].to_s.split : []
              ids.any? && ids.all? { |id| doc.css(%([id="#{id}"])).any? }
            }),
            Gate.new(:invalid_marked, :cross_arm, ->(doc, _html) { doc.css(%(input[aria-invalid="true"])).any? }),
            Gate.new(:required_signalled, :cross_arm, lambda { |doc, _html|
              doc.css("input[required], input[aria-required=true]").any?
            })
          ]
        },
        "form_controls" => {
          "description" => "A notification settings panel: an 'Accept terms' checkbox staged for " \
                           "submit, an instant-effect 'Email alerts' switch, a bookmark toggle, " \
                           "an exclusive list/grid view switcher, a submitting digest-frequency " \
                           "choice, an 'Alert volume' slider, an 'Unsubscribe note' textarea, and " \
                           "a 6-digit 'Confirmation code' entry",
          "gates" => [
            Gate.new(:checkbox_participates_in_the_form, :cross_arm, lambda { |doc, _html|
              # The family boundary: a checkbox STAGES a value - checkbox
              # semantics must be wired to a real form field (a native
              # input or poetry's hidden store), never a button that
              # submits nothing.
              doc.css("input[type=checkbox][name]").any?
            }),
            Gate.new(:switch_semantics, :cross_arm, lambda { |doc, _html|
              # role=switch + aria-checked - announces on/off; a styled
              # checkbox (or a bare div) does not.
              doc.css(%([role="switch"][aria-checked])).any?
            }),
            Gate.new(:pressed_state_exposed, :cross_arm, ->(doc, _html) { doc.css("[aria-pressed]").any? }),
            Gate.new(:exclusive_choice_wears_radio_semantics, :cross_arm, lambda { |doc, _html|
              # An exclusive single-select is a radio group (radiogroup +
              # radio/aria-checked, or native radios) - aria-pressed
              # buttons whose exclusivity lives only in JS promise nothing.
              doc.css(%([role="radiogroup"] [role="radio"][aria-checked])).any? ||
                doc.css("input[type=radio]").any?
            }),
            Gate.new(:slider_wears_the_apg_surface, :cross_arm, lambda { |doc, _html|
              # A slider is operable/announceable only as role=slider with
              # the aria-value trio (or a native input type=range) - a
              # styled div tracks the pointer and nothing else.
              doc.css(%([role="slider"][aria-valuenow][aria-valuemin][aria-valuemax])).any? ||
                doc.css("input[type=range]").any?
            }),
            Gate.new(:code_entry_is_one_autofillable_input, :cross_arm, lambda { |doc, _html|
              # The OTP contract: ONE native input carrying
              # autocomplete=one-time-code (paste + SMS autofill + a
              # single Tab stop) - the per-cell six-input build fails all
              # three ways.
              doc.css(%(input[autocomplete="one-time-code"])).size == 1 &&
                doc.css(%(input[maxlength="1"])).empty?
            }),
            Gate.new(:textarea_labelled_not_placeholdered, :cross_arm, lambda { |doc, _html|
              # Placeholder is NOT a label (the Input rule at textarea
              # scale): every textarea needs a real label pairing.
              textareas = doc.css("textarea")
              textareas.any? && textareas.all? do |control|
                control["aria-label"] || doc.css(%(label[for="#{control["id"]}"])).any?
              end
            }),
            Gate.new(:controls_named, :cross_arm, lambda { |doc, _html|
              doc.css("button, [role=button], [role=checkbox], [role=switch], [role=radio]").all? do |control|
                control.text.strip.length.positive? ||
                  control["aria-label"].to_s.strip.length.positive? ||
                  (control["id"].to_s.strip.length.positive? &&
                    doc.css(%(label[for="#{control["id"]}"])).any?)
              end
            }),
            Gate.new(:content_complete, :cross_arm, lambda { |doc, _html|
              doc.text.include?("Accept terms") && doc.text.include?("Email alerts")
            }),
            Gate.new(:focus_visible_treatment, :cross_arm, ->(_doc, html) { html.include?("focus-visible:") })
          ]
        },
        "alert" => {
          "description" => "A destructive alert 'Payment failed' with a description and a warning icon",
          "gates" => [
            Gate.new(:assertive_announcement, :cross_arm, lambda { |doc, _html|
              doc.css(%([role="alert"], [aria-live="assertive"])).any?
            }),
            Gate.new(:icon_decorative, :cross_arm, lambda { |doc, _html|
              doc.css("svg").all? { |svg| svg["aria-hidden"] == "true" }
            }),
            Gate.new(:title_and_body, :cross_arm, lambda { |doc, _html|
              doc.text.include?("Payment failed") && doc.text.include?("declined")
            })
          ]
        },
        "chat_transcript" => {
          "description" => "A chat transcript: date divider, assistant message with an attachment " \
                           "and a quick reply, and a live 'thinking' status",
          "gates" => [
            Gate.new(:attachment_described, :cross_arm, lambda { |doc, _html|
              doc.text.include?("quarterly-report.pdf") && doc.text.include?("1.2 MB")
            }),
            Gate.new(:quick_replies_are_real_controls, :cross_arm, lambda { |doc, _html|
              doc.xpath(".//*[@onclick]").empty? &&
                doc.xpath(".//*[contains(text(), 'Summarize')]").any? do |n|
                  INTERACTIVE_TAGS.include?(n.name) || n.ancestors.any? { |a| INTERACTIVE_TAGS.include?(a.name) }
                end
            }),
            Gate.new(:live_status_announced, :cross_arm, lambda { |doc, _html|
              doc.css(%([role="status"], [aria-live])).any?
            }),
            Gate.new(:decorative_icons_hidden, :cross_arm, lambda { |doc, _html|
              doc.css("svg").all? { |svg| svg["aria-hidden"] == "true" }
            })
          ]
        },
        "disclosure" => {
          "description" => "An FAQ accordion (one open at a time) plus a 'show advanced options' collapsible",
          "gates" => [
            Gate.new(:triggers_are_real_buttons, :cross_arm, lambda { |doc, _html|
              doc.xpath(".//*[@onclick]").empty? && doc.css("button").size >= 3
            }),
            Gate.new(:expansion_state_exposed, :cross_arm, lambda { |doc, _html|
              doc.css("[aria-expanded=true]").any? && doc.css("[aria-expanded=false]").any?
            }),
            Gate.new(:panels_wired, :cross_arm, lambda { |doc, _html|
              controls = doc.css("[aria-controls]").map { |n| n["aria-controls"] }
              controls.any? && controls.all? { |id| doc.css(%([id="#{id}"])).any? }
            }),
            Gate.new(:headings_present, :cross_arm, ->(doc, _html) { doc.css("h1,h2,h3,h4,h5,h6").any? }),
            Gate.new(:content_complete, :cross_arm, lambda { |doc, _html|
              doc.text.include?("Two business days") && doc.text.include?("Thirty days")
            })
          ]
        },
        "menu" => {
          "description" => "The menus family end-to-end: an app menubar (File/View), a row-actions " \
                           "dropdown menu behind an 'Options' button (account items, a checkbox " \
                           "preference, a destructive delete), and a right-click context menu on " \
                           "the row itself",
          "gates" => [
            Gate.new(:trigger_is_a_real_button, :cross_arm, lambda { |doc, _html|
              doc.xpath(".//*[@onclick]").empty? && doc.css("button").any?
            }),
            Gate.new(:expansion_state_exposed, :cross_arm, lambda { |doc, _html|
              doc.css(%([aria-haspopup="menu"])).any? && doc.css("[aria-expanded]").any?
            }),
            Gate.new(:menu_semantics, :cross_arm, lambda { |doc, _html|
              doc.css("[role=menu]").any? && doc.css("[role=menuitem]").size >= 2
            }),
            Gate.new(:menu_wired_to_trigger, :cross_arm, lambda { |doc, _html|
              controls = doc.css("[aria-haspopup]").filter_map { |node| node["aria-controls"] }
              controls.any? && controls.all? { |id| doc.css(%([id="#{id}"][role=menu])).any? }
            }),
            Gate.new(:toggle_state_accessible, :cross_arm, lambda { |doc, _html|
              doc.css("[role=menuitemcheckbox][aria-checked]").any?
            }),
            Gate.new(:content_complete, :cross_arm, lambda { |doc, _html|
              doc.text.include?("Billing") && doc.text.include?("Delete project")
            })
          ]
        },
        "command_palette" => {
          "description" => "A command palette: a search box filtering a grouped list of app commands " \
                           "(Suggestions: Calendar, Search Emoji, Calculator; Settings: Profile, " \
                           "Billing, Settings - with ⌘ shortcut hints), keyboard-first filter-then-activate",
          "gates" => [
            Gate.new(:combobox_input, :cross_arm, lambda { |doc, _html|
              # The APG editable-combobox surface: a real text input wearing
              # role=combobox + list autocomplete - a bare styled <input>
              # promises nothing to AT.
              doc.css(%(input[role="combobox"][aria-autocomplete="list"])).any?
            }),
            Gate.new(:input_controls_a_listbox, :cross_arm, lambda { |doc, _html|
              controls = doc.css(%(input[role="combobox"])).filter_map { |node| node["aria-controls"] }
              controls.any? && controls.all? { |id| doc.css(%([id="#{id}"][role=listbox])).any? }
            }),
            Gate.new(:listbox_named, :cross_arm, lambda { |doc, _html|
              lists = doc.css("[role=listbox]")
              lists.any? && lists.all? do |list|
                list["aria-label"].to_s.strip.length.positive? ||
                  (list["aria-labelledby"] && doc.css(%([id="#{list["aria-labelledby"]}"])).any?)
              end
            }),
            Gate.new(:options_are_options, :cross_arm, lambda { |doc, _html|
              doc.css("[role=listbox] [role=option]").size >= 4
            }),
            Gate.new(:options_carry_stable_ids, :cross_arm, lambda { |doc, _html|
              # The aria-activedescendant contract: every option needs an id
              # the input can point at.
              options = doc.css("[role=option]")
              options.any? && options.all? { |option| option["id"].to_s.strip.length.positive? }
            }),
            Gate.new(:options_never_focusable, :cross_arm, lambda { |doc, _html|
              # Activedescendant, not roving focus: options must not be tab
              # stops (and a palette input keeps focus for the whole session).
              doc.css("[role=option][tabindex]").empty? &&
                doc.css("[role=listbox] [tabindex]:not([tabindex='-1'])").empty?
            }),
            Gate.new(:groups_labelled, :cross_arm, lambda { |doc, _html|
              groups = doc.css("[role=listbox] [role=group]")
              groups.any? && groups.all? do |group|
                group["aria-labelledby"] && doc.css(%([id="#{group["aria-labelledby"]}"])).any?
              end
            }),
            Gate.new(:no_inline_handlers, :cross_arm, lambda { |doc, _html|
              doc.xpath(".//*[@onclick or @oninput or @onkeydown or @onkeyup]").empty?
            }),
            Gate.new(:content_complete, :cross_arm, lambda { |doc, _html|
              doc.text.include?("Calendar") && doc.text.include?("Billing")
            })
          ]
        },
        "searchable_select" => {
          "description" => "A labelled framework picker: a combobox-role control with a hidden form " \
                           "serialization opening a type-to-filter popup over Next.js/SvelteKit/" \
                           "Nuxt.js/Remix/Astro options",
          "gates" => [
            Gate.new(:combobox_role_control, :cross_arm, lambda { |doc, _html|
              # The APG surface: a control WEARING role=combobox with a
              # dynamic expansion state - a styled button div promises
              # nothing to AT.
              doc.css("[role=combobox][aria-expanded]").any?
            }),
            Gate.new(:combobox_controls_a_listbox, :cross_arm, lambda { |doc, _html|
              controls = doc.css("[role=combobox]").filter_map { |node| node["aria-controls"] }
              controls.any? && controls.all? { |id| doc.css(%([id="#{id}"][role=listbox])).any? }
            }),
            Gate.new(:options_are_options, :cross_arm, lambda { |doc, _html|
              doc.css("[role=listbox] [role=option]").size >= 4
            }),
            Gate.new(:filter_input_wears_list_autocomplete, :cross_arm, lambda { |doc, _html|
              doc.css(%(input[aria-autocomplete="list"])).any?
            }),
            Gate.new(:combobox_named, :cross_arm, lambda { |doc, _html|
              controls = doc.css("[role=combobox]")
              controls.any? && controls.all? do |control|
                control["aria-label"].to_s.strip.length.positive? ||
                  (control["aria-labelledby"] && doc.css(%([id="#{control["aria-labelledby"]}"])).any?) ||
                  (control["id"] && doc.css(%(label[for="#{control["id"]}"])).any?)
              end
            }),
            Gate.new(:options_never_focusable, :cross_arm, lambda { |doc, _html|
              # Activedescendant, not roving focus: options must not be
              # tab stops.
              doc.css("[role=option][tabindex]").empty? &&
                doc.css("[role=listbox] [tabindex]:not([tabindex='-1'])").empty?
            }),
            Gate.new(:no_inline_handlers, :cross_arm, lambda { |doc, _html|
              doc.xpath(".//*[@onclick or @oninput or @onkeydown or @onkeyup]").empty?
            }),
            Gate.new(:content_complete, :cross_arm, lambda { |doc, _html|
              doc.text.include?("Next.js") && doc.text.include?("SvelteKit")
            })
          ],
          # Task-scoped poetry diagnostics (never run against a raw arm -
          # the A/B honesty rule): the form story no raw popup ever ships.
          "poetry_gates" => [
            Gate.new(:hidden_native_select_serializes, :poetry_only, lambda { |doc, _html|
              native = doc.css(%(select[data-slot="combobox-native"][name])).first
              !native.nil? && native["aria-hidden"] == "true" &&
                native.css(%(option[value="next.js"])).any?
            }),
            Gate.new(:twin_write_pair_present, :poetry_only, lambda { |doc, _html|
              options = doc.css("[role=option]")
              options.any? && options.all? do |option|
                (option["aria-selected"] == "true") == option.key?("data-selected")
              end && doc.css(%([role=option][aria-selected="true"][data-selected])).size == 1
            })
          ]
        },
        "overlay" => {
          "description" => "A destructive 'Delete API key' confirmation that must be answered " \
                           "(alert dialog), plus a 'Filter results' panel sliding in from the " \
                           "right edge (sheet)",
          "gates" => [
            Gate.new(:two_modal_surfaces, :cross_arm, lambda { |doc, _html|
              doc.css("dialog, [role=dialog], [role=alertdialog]").size >= 2
            }),
            Gate.new(:confirm_has_alertdialog_semantics, :cross_arm, lambda { |doc, _html|
              doc.css("[role=alertdialog]").any?
            }),
            Gate.new(:surfaces_labelled, :cross_arm, lambda { |doc, _html|
              surfaces = doc.css("dialog, [role=dialog], [role=alertdialog]")
              surfaces.any? && surfaces.all? { |surface| surface["aria-labelledby"] || surface["aria-label"] }
            }),
            Gate.new(:confirmation_described, :cross_arm, lambda { |doc, _html|
              confirm = doc.css("[role=alertdialog]").first
              ids = confirm ? confirm["aria-describedby"].to_s.split : []
              ids.any? && ids.all? { |id| doc.css(%([id="#{id}"])).any? }
            }),
            Gate.new(:explicit_choice_controls, :cross_arm, lambda { |doc, _html|
              labels = doc.css("button, [role=button]").map { |control| control.text.strip }
              labels.include?("Cancel") && labels.any? { |label| label.include?("Delete API key") }
            }),
            Gate.new(:triggers_are_real_buttons, :cross_arm, lambda { |doc, _html|
              doc.xpath(".//*[@onclick]").empty? && doc.css("button").size >= 2
            }),
            Gate.new(:focus_visible_treatment, :cross_arm, ->(_doc, html) { html.include?("focus-visible:") })
          ]
        },
        "floating" => {
          "description" => "The popper-consumer trio end-to-end: a 'Dimensions' popover behind an " \
                           "'Open popover' button hosting a small form, an icon-only 'Add to library' " \
                           "control with a tooltip, and an '@nextjs' link enriched with a profile " \
                           "hover-card whose content lives at the link's destination",
          "gates" => [
            Gate.new(:popover_dialog_semantics, :cross_arm, ->(doc, _html) { doc.css("[role=dialog]").any? }),
            Gate.new(:tooltip_semantics, :cross_arm, ->(doc, _html) { doc.css("[role=tooltip]").any? }),
            Gate.new(:tooltip_never_interactive, :cross_arm, lambda { |doc, _html|
              doc.css("[role=tooltip]").all? { |tip| tip.css("a, button, input, select, textarea").empty? }
            }),
            Gate.new(:icon_controls_named, :cross_arm, lambda { |doc, _html|
              doc.css("button").all? do |control|
                control.text.strip.length.positive? || control["aria-label"].to_s.strip.length.positive?
              end
            }),
            Gate.new(:hover_trigger_is_a_real_link, :cross_arm, lambda { |doc, _html|
              mention = doc.xpath(".//*[normalize-space(text())='@nextjs']")
                           .find { |node| node.name == "a" || node.ancestors.any? { |a| a.name == "a" } }
              link = mention && (mention.name == "a" ? mention : mention.ancestors.find { |a| a.name == "a" })
              # The reachable-elsewhere rule's precondition: a REAL
              # destination, not an href="#" placeholder.
              !link.nil? && !link["href"].to_s.strip.empty? && link["href"] != "#"
            }),
            Gate.new(:hover_preview_not_interactive, :cross_arm, lambda { |doc, _html|
              # Locate the preview body by its content: pointer-only
              # surfaces must not hide interactive controls (a Follow
              # button some users can never press).
              joined = doc.xpath(".//*[contains(text(), 'Joined December 2021')]").first
              container = joined&.ancestors&.find { |node| node.css("h4, .font-semibold").any? } || joined&.parent
              !container.nil? && container.css("button, input, select, textarea").empty?
            }),
            Gate.new(:trigger_advertises_the_popup, :cross_arm, lambda { |doc, _html|
              controls = doc.css(%([aria-haspopup="dialog"])).filter_map { |node| node["aria-controls"] }
              controls.any? && controls.all? { |id| doc.css(%([id="#{id}"][role=dialog])).any? }
            }),
            Gate.new(:expansion_state_exposed, :cross_arm, lambda { |doc, _html|
              doc.css(%([aria-haspopup="dialog"][aria-expanded])).any?
            }),
            Gate.new(:dialog_named, :cross_arm, lambda { |doc, _html|
              doc.css("[role=dialog]").all? do |dialog|
                dialog["aria-label"] || (dialog["aria-labelledby"] &&
                  doc.css(%([id="#{dialog["aria-labelledby"]}"])).any?)
              end
            }),
            Gate.new(:triggers_are_real_buttons, :cross_arm, lambda { |doc, _html|
              doc.xpath(".//*[@onclick]").empty? && doc.css("button").any?
            }),
            Gate.new(:form_labels_wired, :cross_arm, lambda { |doc, _html|
              inputs = doc.css("input")
              inputs.any? && inputs.all? { |input| doc.css(%(label[for="#{input["id"]}"])).any? }
            }),
            Gate.new(:focus_visible_treatment, :cross_arm, ->(_doc, html) { html.include?("focus-visible:") })
          ]
        },
        "toast" => {
          "description" => "A notifications region hosting a 'Saved' success toast and a destructive " \
                           "'Payment failed' toast with a 'Retry' action",
          "gates" => [
            Gate.new(:region_labelled, :cross_arm, lambda { |doc, _html|
              doc.css("[role=region][aria-label]").any?
            }),
            Gate.new(:announced_to_at, :cross_arm, lambda { |doc, _html|
              doc.css("[role=status], [role=alert], [aria-live]").any?
            }),
            Gate.new(:retry_is_a_real_button, :cross_arm, lambda { |doc, _html|
              doc.xpath(".//button[contains(normalize-space(.), 'Retry')]").any?
            }),
            Gate.new(:no_focus_steal, :cross_arm, ->(doc, _html) { doc.css("[autofocus]").empty? }),
            Gate.new(:content_complete, :cross_arm, lambda { |doc, _html|
              doc.text.include?("Saved") && doc.text.include?("Payment failed")
            }),
            Gate.new(:dismissal_is_real_wiring, :cross_arm, lambda { |doc, _html|
              doc.xpath(".//*[@onclick]").empty? && doc.css("button").any?
            }),
            Gate.new(:focus_visible_treatment, :cross_arm, ->(_doc, html) { html.include?("focus-visible:") })
          ]
        },
        "primitives" => {
          "description" => "A loading state: a labelled spinner, a skeleton row, a separator, and a ⌘K hint",
          "gates" => [
            Gate.new(:spinner_announces_loading, :cross_arm, lambda { |doc, _html|
              status = doc.css('[role="status"]').first
              status && (status["aria-label"].to_s.strip.length.positive? || status.text.strip.length.positive?)
            }),
            Gate.new(:shortcut_keys_are_real_kbd, :cross_arm, ->(doc, _html) { doc.css("kbd").length >= 2 })
          ]
        },
        "pagination" => {
          "description" => "Pagination for page 4 of 10, with a current-page marker",
          "gates" => [
            Gate.new(:navigation_landmark, :cross_arm, lambda { |doc, _html|
              nav = doc.css('nav, [role="navigation"]').first
              nav && nav["aria-label"].to_s.strip.length.positive?
            }),
            Gate.new(:current_page_marked, :cross_arm, ->(doc, _html) { doc.css('[aria-current="page"]').any? }),
            Gate.new(:pages_are_real_links, :cross_arm, lambda { |doc, _html|
              doc.css("a").any? && doc.css("a").all? { |a| a["href"].to_s.strip.length.positive? }
            })
          ]
        },
        "empty_state" => {
          "description" => "A 'no projects yet' empty state: an icon tile, a title, a description, " \
                           "and create/import actions",
          "gates" => [
            Gate.new(:title_is_a_real_heading, :cross_arm, lambda { |doc, _html|
              doc.css("h1, h2, h3, h4, h5, h6").any?
            }),
            Gate.new(:actions_are_focusable, :cross_arm, lambda { |doc, _html|
              doc.css("button, a[href]").length >= 2
            }),
            Gate.new(:actions_are_real_wiring, :cross_arm, ->(doc, _html) { doc.xpath(".//*[@onclick]").empty? })
          ]
        },
        "app_shell" => {
          "description" => "An application shell: a collapsible sidebar with a Platform nav group " \
                           "(Dashboard active) and a main content area with a collapse toggle",
          "gates" => [
            Gate.new(:content_is_a_main_landmark, :cross_arm, ->(doc, _html) { doc.css("main").any? }),
            Gate.new(:nav_items_are_real_links, :cross_arm, lambda { |doc, _html|
              links = doc.css('[data-slot="sidebar-menu-button"], aside a, nav a')
              links.any? && doc.xpath(".//*[@onclick]").empty?
            }),
            Gate.new(:collapse_is_coordinated_state, :cross_arm, lambda { |doc, _html|
              # The tell: a real collapse flips a data-state the CSS reads;
              # the raw arm toggles via an onclick with no shared state.
              doc.css("[data-state]").any? && doc.xpath(".//*[@onclick]").empty?
            })
          ]
        },
        "site_nav" => {
          "description" => "A site navigation bar: a Products dropdown of links, plus Pricing and " \
                           "Docs destinations",
          "gates" => [
            Gate.new(:nav_landmark, :cross_arm, ->(doc, _html) { doc.css("nav[aria-label]").any? }),
            Gate.new(:disclosure_announces, :cross_arm, lambda { |doc, _html|
              doc.css("button[aria-expanded][aria-controls]").any?
            }),
            Gate.new(:reachable_without_hover, :cross_arm, lambda { |doc, _html|
              doc.xpath(".//*[@onmouseover or @onmouseout or @onclick]").empty?
            }),
            Gate.new(:no_menu_role_abuse, :cross_arm, ->(doc, _html) { doc.css("[role=menu], [role=menuitem]").empty? })
          ]
        },
        "artwork_carousel" => {
          "description" => "A three-slide artwork carousel with previous/next controls",
          "gates" => [
            Gate.new(:carousel_region_semantics, :cross_arm, lambda { |doc, _html|
              doc.css('[aria-roledescription="carousel"][aria-label]').any? &&
                doc.css('[aria-roledescription="slide"]').length >= 3
            }),
            Gate.new(:slides_reachable_without_js, :cross_arm, lambda { |doc, _html|
              # The tell: a transform track strands content behind the
              # buttons; a real scroll container keeps it reachable.
              doc.xpath('.//*[contains(@style, "translateX")]').empty? && doc.xpath(".//*[@onclick]").empty?
            })
          ]
        },
        "split_editor" => {
          "description" => "A two-pane resizable split (Files | Editor) with a draggable divider",
          "gates" => [
            Gate.new(:splitter_wears_the_apg_surface, :cross_arm, lambda { |doc, _html|
              doc.css('[role="separator"][tabindex="0"][aria-valuenow]').any?
            }),
            Gate.new(:resize_is_real_wiring, :cross_arm, lambda { |doc, _html|
              doc.xpath(".//*[@onmousedown or @onclick]").empty?
            })
          ]
        },
        "mobile_sheet" => {
          "description" => "A bottom drawer for setting a daily activity goal: trigger, title, " \
                           "description, a Submit action, and a swipe handle",
          "gates" => [
            Gate.new(:modal_semantics, :cross_arm, ->(doc, _html) { doc.css("dialog, [role=dialog]").any? }),
            Gate.new(:labelled_overlay, :cross_arm, lambda { |doc, _html|
              overlay = doc.css("dialog, [role=dialog]").first
              !overlay.nil? && !(overlay["aria-labelledby"] || overlay["aria-label"]).nil?
            }),
            Gate.new(:dismissal_is_real_wiring, :cross_arm, ->(doc, _html) { doc.xpath(".//*[@onclick]").empty? })
          ]
        },
        "scrollable_tags" => {
          "description" => "A bounded, scrollable list of 20 version tags in a 12rem box",
          "gates" => [
            Gate.new(:scroll_region_is_keyboard_reachable, :cross_arm, lambda { |doc, _html|
              doc.css('[tabindex="0"]').any?
            }),
            Gate.new(:scroll_region_is_named, :cross_arm, lambda { |doc, _html|
              doc.css('[role="region"][aria-label]').any?
            })
          ]
        },
        "settings_tabs" => {
          "description" => "Account settings tabs (Account / Password / Notifications) with the " \
                           "first tab active and its panel visible",
          "gates" => [
            Gate.new(:tablist_semantics, :cross_arm, lambda { |doc, _html|
              doc.css('[role="tablist"] [role="tab"]').length >= 3 && doc.css('[role="tabpanel"]').any?
            }),
            Gate.new(:selection_announced_and_wired, :cross_arm, lambda { |doc, _html|
              active = doc.css('[role="tab"][aria-selected="true"]')
              active.length == 1 && active.first["aria-controls"].to_s.strip.length.positive?
            }),
            Gate.new(:switching_is_real_wiring, :cross_arm, ->(doc, _html) { doc.xpath(".//*[@onclick]").empty? })
          ]
        },
        "filter_toolbar" => {
          "description" => "A filter toolbar: a search box with a leading icon and ⌘K hint, a sort " \
                           "dropdown, and a List/Grid view switch",
          "gates" => [
            Gate.new(:controls_are_labelled, :cross_arm, lambda { |doc, _html|
              %w[input select].all? do |kind|
                doc.css(kind).all? do |el|
                  doc.css(%(label[for="#{el["id"]}"])).any? || el["aria-label"].to_s.strip.length.positive?
                end
              end
            }),
            Gate.new(:composites_are_groups, :cross_arm, lambda { |doc, _html|
              doc.css('[role="group"]').length >= 2
            }),
            Gate.new(:sort_is_a_real_select, :cross_arm, ->(doc, _html) { doc.css("select option").length >= 2 })
          ]
        },
        "user_directory" => {
          "description" => "A team directory: a breadcrumb trail (Home / Team / Directory), then a " \
                           "list of member rows - avatar, name, description, and a Message action",
          "gates" => [
            Gate.new(:breadcrumb_is_a_landmark_with_current, :cross_arm, lambda { |doc, _html|
              doc.css('nav[aria-label] [aria-current="page"]').any?
            }),
            Gate.new(:members_are_a_list, :cross_arm, lambda { |doc, _html|
              doc.css('ul, ol, [role="list"]').any?
            }),
            Gate.new(:avatars_have_accessible_names, :cross_arm, lambda { |doc, _html|
              # The tell: a naked <img> avatar carries no name and no fallback.
              # Named = a role=img root with a label, or an img with real alt;
              # an alt="" img is fine ONLY inside a labelled role=img root
              # (poetry's layered-fallback contract).
              named = doc.css('[role="img"][aria-label], img[alt]:not([alt=""])')
              bare = doc.css("img").reject do |img|
                img["alt"].to_s.strip.length.positive? ||
                  img.xpath('ancestor::*[@role="img"][@aria-label]').any?
              end
              named.any? && bare.empty?
            })
          ]
        },
        "upload_progress" => {
          "description" => "A determinate upload progress bar at 60%, with a visible label and value",
          "gates" => [
            Gate.new(:progressbar_announces, :cross_arm, lambda { |doc, _html|
              doc.css('[role="progressbar"][aria-valuenow]').any?
            }),
            Gate.new(:progressbar_named, :cross_arm, lambda { |doc, _html|
              doc.css('[role="progressbar"][aria-label], [role="progressbar"][aria-labelledby]').any?
            })
          ]
        },
        "data_table" => {
          "description" => "A sortable, filterable invoices table: sorted by invoice number ascending, " \
                           "with a filter box and pagination",
          "gates" => [
            Gate.new(:sorted_column_announces, :cross_arm, ->(doc, _html) { doc.css("th[aria-sort]").any? }),
            Gate.new(:sorting_is_real_navigation, :cross_arm, lambda { |doc, _html|
              # The tell: sort affordances must be links (keyboard + shareable
              # URL state), never onclick handlers.
              doc.xpath(".//*[@onclick or @oninput]").empty? && doc.css("th a[href]").any?
            }),
            Gate.new(:filter_is_labelled, :cross_arm, lambda { |doc, _html|
              input = doc.css("input[placeholder]").first
              input && (doc.css(%(label[for="#{input["id"]}"])).any? || input["aria-label"].to_s.strip.length.positive?)
            })
          ]
        },
        "table" => {
          "description" => "An invoices table with a caption, column headers, and a footer total",
          "gates" => [
            Gate.new(:real_table, :cross_arm, ->(doc, _html) { doc.css("table").any? }),
            Gate.new(:column_headers_are_th, :cross_arm, lambda { |doc, _html|
              # The tell: real column headers are <th>, not styled divs.
              doc.css("th").length >= 3
            }),
            Gate.new(:caption_present, :cross_arm, ->(doc, _html) { doc.css("caption").any? })
          ]
        },
        "card" => {
          "description" => "A plan card: title, description, a 'beta' badge, body copy, and a 'Learn more' link",
          "gates" => [
            Gate.new(:heading_semantics, :cross_arm, ->(doc, _html) { doc.css("h1,h2,h3,h4,h5,h6").any? }),
            Gate.new(:real_link, :cross_arm, lambda { |doc, _html|
              doc.css("a").any? && doc.css("a").all? { |a| a["href"].to_s.strip.length.positive? }
            }),
            Gate.new(:badge_not_interactive, :cross_arm, lambda { |doc, _html|
              badge = doc.xpath(".//*[normalize-space(text())='beta']").first
              !badge.nil? && !INTERACTIVE_TAGS.include?(badge.name) &&
                badge.ancestors.none? { |node| INTERACTIVE_TAGS.include?(node.name) }
            })
          ]
        }
      }.freeze

      POETRY_ONLY = [
        Gate.new(:stayed_in_system, :poetry_only, lambda { |doc, _html|
          # A control is in-system as a component root (data-component) OR
          # as a named part of one (data-slot - e.g. a Bubble quick-reply).
          doc.css("button, [role=button]").all? { |control| control["data-component"] || control["data-slot"] }
        }),
        Gate.new(:registry_conformance, :poetry_only, lambda { |doc, _html|
          registry = Poetry::Core::Registry.new(source_root: Poetry::Ui.root).entries
          known = registry.values.map { |entry| entry["class_name"].demodulize.underscore }
          titles = registry.keys.map { |path| path.split("/").last }
          doc.css("[data-component]").all? { |node| (titles + known).include?(node["data-component"]) }
        })
      ].freeze

      def arms(task)
        Dir.glob(Poetry::Ui.root.join("eval/arms/#{task}/*.html.erb")).to_h do |path|
          [File.basename(path, ".html.erb"), File.read(path)]
        end
      end

      def scorecard
        exercised = []
        tasks = TASKS.to_h do |task, spec|
          results = arms(task).to_h { |arm, erb| [arm, score_arm(task, arm, erb, exercised)] }
          [task, { "description" => spec["description"], "arms" => results }]
        end
        {
          "generated_note" => "Frozen arms, deterministic gates. cross_arm gates are the only " \
                              "comparable numbers; poetry_only gates are diagnostics (they cannot " \
                              "fail a non-poetry arm).",
          "tasks" => tasks,
          "components_exercised" => exercised.uniq.sort
        }
      end

      def write!(path = Poetry::Ui.root.join("tmp/eval-scorecard.json"))
        card = scorecard
        path.dirname.mkpath
        path.write(JSON.pretty_generate(card))
        [card, path]
      end

      private

      def score_arm(task, arm, erb, exercised)
        html = render(erb)
        doc = Nokogiri::HTML5.fragment(html)
        gates = TASKS.fetch(task)["gates"] + UNIVERSAL
        cross = gates.to_h { |gate| gate.run(doc, html) }
        result = {
          "cross_arm" => cross,
          "cross_arm_score" => "#{cross.values.count(true)}/#{cross.size}"
        }
        if arm.include?("poetry")
          diagnostics = POETRY_ONLY + TASKS.fetch(task).fetch("poetry_gates", [])
          result["poetry_only_diagnostics"] = diagnostics.to_h { |gate| gate.run(doc, html) }
          # poetry check: the mechanical gate on the SOURCE - the
          # poetry arm's ERB must lint clean (no error-severity findings)
          # before the LLM judge ever scores it. An agent self-corrects here.
          result["poetry_only_diagnostics"]["poetry_check"] = poetry_check_clean?(erb)
          exercised.concat(doc.css("[data-component]").map { |node| node["data-component"] })
        end
        result
      end

      def poetry_check_clean?(erb)
        Poetry::Core::Check.lint(erb, catalog: check_catalog).none? { |finding| finding.severity == :error }
      end

      def check_catalog
        @check_catalog ||= Poetry::Core::Check::Catalog.from_registry(
          Poetry::Ui.root,
          helpers: Poetry::Ui::ComponentsHelper.public_instance_methods(false).grep(/\Apoetry_/)
        )
      end

      def render(erb)
        ApplicationController.renderer.render(inline: erb, layout: false)
      end
    end
  end
end
