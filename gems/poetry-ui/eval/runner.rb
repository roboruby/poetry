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
