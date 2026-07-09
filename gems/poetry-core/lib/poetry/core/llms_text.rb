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

      # The lean index: one line per component (+ the blocks catalog).
      def index
        lines = @registry.entries.map do |path, entry|
          "- #{title(path)}: `#{helper(path)}` - #{surface_summary(entry)}"
        end
        "#{PREAMBLE}\n## Components\n\n#{lines.join("\n")}\n#{blocks_index}"
      end

      # The full contracts: props, slots, elements, and agent rules - plus
      # every block's source, so an agent holding this file can start a
      # screen from a vetted composition without another fetch.
      def full
        sections = @registry.entries.map { |path, entry| component_section(path, entry) }
        "#{PREAMBLE}\n#{sections.join("\n")}#{blocks_full}"
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
        slots = entry["slots"].map { |slot| slot_summary(slot) }
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
          details << "format: #{prop["format"]}" if prop["format"]
          "- `#{prop["name"]}:` (#{prop["type"]})#{" - #{details.join(", ")}" if details.any?}"
        end
      end

      # A typed slot renders another component: the call takes THAT
      # component's props, never a render block (with_icon(name: ...) - the
      # W2 alert crash was an agent block-form guess this line now
      # forecloses). Untyped slots take blocks; many-slots say so; a
      # polymorphic slot lists its with_<type> setters - and when they are
      # all kwargs-only, says so (the W2r menu crash guessed a
      # type-as-argument dispatch no setter has).
      def slot_summary(slot)
        qualifiers = []
        qualifiers << "many" if slot["many"]
        if slot["types"]
          convention = kwargs_only_setters?(slot) ? " - one with_<type> setter each, options as keywords" : ""
          qualifiers << "types #{slot["types"].join("|")}#{convention}"
        end
        qualifiers << "takes #{helper(slot["component"])} props, not a block" if slot["component"]
        "#{slot["name"]}#{" (#{qualifiers.join("; ")})" if qualifiers.any?}"
      end

      def kwargs_only_setters?(slot)
        args = slot["setter_args"]
        # A type with no tracked arity (rest-signature) is unknowable - the
        # claim only holds when every setter is known kwargs-only.
        args && slot["types"].all? { |type| args[type]&.zero? }
      end

      # The blocks catalog (Blocks v1): vetted composed screens, one
      # altitude above components. The index teaches the decision
      # hierarchy - start a SCREEN from a block, compose atoms for what no
      # block covers.
      def blocks_index
        blocks = @registry.blocks
        return "" if blocks.nil? || blocks.empty?

        lines = blocks.map do |name, entry|
          "- #{entry["title"]} (`#{name}`): #{entry["description"]} " \
            "[composes: #{entry["components"].join(", ")}]"
        end
        <<~TEXT

          ## Blocks

          Start a screen from a vetted block, then edit it in place:
          `bin/rails g poetry:block <name>` copies it into app/views/blocks/
          as source the app owns (--list to browse); the MCP `describe_block`
          tool returns the same source boot-free. Blocks carry the composed
          patterns - containment, status color-coding, page furniture,
          realistic content - so a screen starts composed, not blank.

          #{lines.join("\n")}
        TEXT
      end

      def blocks_full
        blocks = @registry.blocks
        return "" if blocks.nil? || blocks.empty?

        sections = blocks.map do |name, entry|
          source = @registry.source_root.join(entry.fetch("template")).read
          ["## Block: #{entry["title"]} (`#{name}`)", "",
           entry["description"],
           "Composes: #{entry["components"].join(", ")}. " \
           "Generate: `bin/rails g poetry:block #{name}`.",
           "Source (adapt freely - the sample content is meant to be replaced):", "",
           source.sub(/\A<%#\s*poetry:block[^%]*%>\n?/, "").rstrip].join("\n")
        end
        "\n#{sections.join("\n\n")}\n"
      end
    end
  end
end
