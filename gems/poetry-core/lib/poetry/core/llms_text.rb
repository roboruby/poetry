# frozen_string_literal: true

module Poetry
  module Core
    # Generates llms.txt (the index) and llms-full.txt (full contracts) from
    # the component registry - never hand-maintained, so the LLM-facing docs
    # can't drift from the code (the shadcn convergence; layer 2
    # of the discoverability scorecard).
    class LlmsText
      PREAMBLE = <<~TEXT
        # Poetry for Rails

        > poetry is an AI-native, Rails-first component library: accessible,
        > themeable ViewComponents on semantic design tokens. Agents compose
        > from the approved catalog below instead of writing raw markup.

        Preference hierarchy: tokens > utilities; components > raw markup;
        variants > one-off classes; slots > custom HTML. Render components
        with their `poetry_<name>` helpers.
      TEXT

      def initialize(registry:)
        @registry = registry
      end

      # The lean index: one line per component.
      def index
        lines = @registry.entries.map do |path, entry|
          title = path.split("/").last
          "- #{title}: `poetry_#{title}` - #{surface_summary(entry)}"
        end
        "#{PREAMBLE}\n## Components\n\n#{lines.join("\n")}\n"
      end

      # The full contracts: props, slots, elements, and agent rules.
      def full
        sections = @registry.entries.map { |path, entry| component_section(path, entry) }
        "#{PREAMBLE}\n#{sections.join("\n")}"
      end

      private

      def surface_summary(entry)
        parts = entry["styles"].map do |style|
          values = style["variants"] ? style["variants"].join("|") : style["type"]
          "#{style["name"]}: #{values}"
        end
        parts.empty? ? "no style attributes" : parts.join("; ")
      end

      def component_section(path, entry)
        title = path.split("/").last
        lines = ["## #{title} (`poetry_#{title}`)", ""]
        lines << "Class: #{entry["class_name"]} - BEM block `#{entry["bem_block"]}`."
        lines.concat(prop_lines(entry))
        slots = entry["slots"].map { |slot| "#{slot["name"]}#{" (many)" if slot["many"]}" }
        lines << "Slots: #{slots.join(", ")}." if slots.any?
        (entry["agent_rules"] || []).each { |rule| lines << "- RULE: #{rule}" }
        "#{lines.join("\n")}\n"
      end

      def prop_lines(entry)
        (entry["styles"] + entry["options"]).map do |prop|
          details = []
          details << "one of #{prop["variants"].join("|")}" if prop["variants"]
          details << "default #{prop["default"].inspect}" if prop.key?("default")
          details << "required" if prop["required"]
          "- `#{prop["name"]}:` (#{prop["type"]})#{" - #{details.join(", ")}" if details.any?}"
        end
      end
    end
  end
end
