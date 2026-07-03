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
                           "submit, an instant-effect 'Email alerts' switch, a bookmark toggle, and " \
                           "an exclusive list/grid view switcher",
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
          result["poetry_only_diagnostics"] = POETRY_ONLY.to_h { |gate| gate.run(doc, html) }
          exercised.concat(doc.css("[data-component]").map { |node| node["data-component"] })
        end
        result
      end

      def render(erb)
        ApplicationController.renderer.render(inline: erb, layout: false)
      end
    end
  end
end
