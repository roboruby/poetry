# frozen_string_literal: true

require "json"
require "nokogiri"

module Poetry
  module Eval
    # The thinnest eval slice: renders each arm of a
    # Button-scoped task and runs the gate array, emitting the first
    # scorecard. This validates the HARNESS - arms render, gates run, the
    # scorecard emits - not the thesis; thesis-level receipts accrue from
    # M6 as real components, the skill, and live generation land.
    #
    # The scorer-portability rule (the A/B honesty split): CROSS_ARM gates
    # run identically on every arm and are the only comparable numbers;
    # POETRY_ONLY gates cannot structurally fail a non-poetry artifact and
    # are reported as diagnostics, never as comparisons.
    class Runner
      TASK = "A destructive 'Delete account' button with a leading trash icon"

      Gate = Struct.new(:name, :scope, :check) do
        def run(doc, html)
          [name, check.call(doc, html)]
        end
      end

      CROSS_ARM = [
        Gate.new(:renders, :cross_arm, ->(doc, _html) { doc.css("button, [role=button]").any? }),
        Gate.new(:accessible_name, :cross_arm, lambda { |doc, _html|
          control = doc.css("button, [role=button]").first
          control && (control.text.strip.length.positive? || control["aria-label"].to_s.strip.length.positive?)
        }),
        Gate.new(:explicit_type, :cross_arm, lambda { |doc, _html|
          types = %w[button submit reset]
          doc.css("button").all? { |button| types.include?(button["type"]) }
        }),
        Gate.new(:focus_visible_treatment, :cross_arm, ->(_doc, html) { html.include?("focus-visible:") }),
        Gate.new(:no_raw_colors, :cross_arm, lambda { |_doc, html|
          # The cheapest slop-detector rule: arbitrary color values
          # bypass the theme. Checkable on ANY html, no Herb needed.
          !html.match?(/\b(?:bg|text|border|ring|stroke|fill)-\[(?:#|rgb|hsl|oklch)/)
        })
      ].freeze

      POETRY_ONLY = [
        Gate.new(:stayed_in_system, :poetry_only, lambda { |doc, _html|
          doc.css("button, [role=button]").all? { |control| control["data-component"] }
        }),
        Gate.new(:registry_conformance, :poetry_only, lambda { |doc, _html|
          registry = Poetry::Core::Registry.new(source_root: Poetry::Ui.root).entries
          known = registry.values.map { |entry| entry["class_name"].demodulize.underscore }
          titles = registry.keys.map { |path| path.split("/").last }
          doc.css("[data-component]").all? { |node| (titles + known).include?(node["data-component"]) }
        })
      ].freeze

      def arms
        Dir.glob(Poetry::Ui.root.join("eval/arms/*.html.erb")).to_h do |path|
          [File.basename(path, ".html.erb"), File.read(path)]
        end
      end

      def scorecard
        results = arms.to_h { |name, erb| [name, score_arm(name, erb)] }
        {
          "task" => TASK,
          "generated_note" => "M3.5 plumbing slice: frozen arms, deterministic gates. " \
                              "cross_arm gates are the only comparable numbers; " \
                              "poetry_only gates are diagnostics (they cannot fail a non-poetry arm).",
          "arms" => results
        }
      end

      def write!(path = Poetry::Ui.root.join("tmp/eval-scorecard.json"))
        card = scorecard
        path.dirname.mkpath
        path.write(JSON.pretty_generate(card))
        [card, path]
      end

      private

      def score_arm(name, erb)
        html = render(erb)
        doc = Nokogiri::HTML5.fragment(html)
        cross = CROSS_ARM.to_h { |gate| gate.run(doc, html) }
        result = {
          "cross_arm" => cross,
          "cross_arm_score" => "#{cross.values.count(true)}/#{cross.size}"
        }
        result["poetry_only_diagnostics"] = POETRY_ONLY.to_h { |gate| gate.run(doc, html) } if name.include?("poetry")
        result
      end

      def render(erb)
        ApplicationController.renderer.render(inline: erb, layout: false)
      end
    end
  end
end
