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

        Verify your markup with `poetry check` (rake poetry:check) before it
        renders - it validates components, options, variants, and Stimulus
        wiring against these contracts. Testing doctrine: docs/testing.md.
      TEXT

      def initialize(registry:)
        @registry = registry
      end

      # The lean index: one line per component.
      def index
        lines = @registry.entries.map do |path, entry|
          "- #{title(path)}: `#{helper(path)}` - #{surface_summary(entry)}"
        end
        "#{PREAMBLE}\n## Components\n\n#{lines.join("\n")}\n"
      end

      # The full contracts: props, slots, elements, and agent rules.
      def full
        sections = @registry.entries.map { |path, entry| component_section(path, entry) }
        "#{PREAMBLE}\n#{sections.join("\n")}"
      end

      private

      # The helper is poetry_ + the path under the ui/ namespace, so
      # command/dialog -> poetry_command_dialog (not the last-segment
      # poetry_dialog, which collides with the top-level dialog).
      def title(path) = path.split("/").drop(2).join("_")
      def helper(path) = "poetry_#{title(path)}"

      def surface_summary(entry)
        parts = entry["styles"].map do |style|
          values = style["variants"] ? style["variants"].join("|") : style["type"]
          "#{style["name"]}: #{values}"
        end
        parts.empty? ? "no style attributes" : parts.join("; ")
      end

      def component_section(path, entry)
        lines = ["## #{title(path)} (`#{helper(path)}`)", ""]
        lines << "Class: #{entry["class_name"]} - BEM block `#{entry["bem_block"]}`."
        lines.concat(prop_lines(entry))
        slots = entry["slots"].map { |slot| "#{slot["name"]}#{" (many)" if slot["many"]}" }
        lines << "Slots: #{slots.join(", ")}." if slots.any?
        lines.concat(wiring_lines(entry))
        (entry["agent_rules"] || []).each { |rule| lines << "- RULE: #{rule}" }
        "#{lines.join("\n")}\n"
      end

      # The Stimulus wiring surface (N7 W3): the controllers a component
      # renders, each with the targets / values / actions an agent may wire
      # by hand and the events it may listen for (N13 W1). Base UI
      # vocabulary. Absent for static components.
      def wiring_lines(entry)
        (entry["controllers"] || []).map do |controller|
          facets = []
          facets << "targets #{controller["targets"].join(", ")}" if controller["targets"].any?
          facets << "values #{controller["values"].join(", ")}" if controller["values"].any?
          facets << "actions #{controller["actions"].join(", ")}" if controller["actions"].any?
          facets << "events #{controller["events"].join(", ")}" if (controller["events"] || []).any?
          "- WIRING `#{controller["identifier"]}`#{": #{facets.join("; ")}" unless facets.empty?}"
        end
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
