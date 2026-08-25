# frozen_string_literal: true

module Poetry
  module Core
    # Generates llms.txt (the index) and llms-full.txt (full contracts) from
    # the component registry - never hand-maintained, so the LLM-facing docs
    # can't drift from the code.
    #
    # @example
    #   Poetry::Core::LlmsText.new(registry: registry).index
    #
    # @api private
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
        wiring against these contracts. Testing doctrine: the Testing guide on the poetry docs site.
      TEXT

      def initialize(registry:)
        @registry = registry
      end

      # The lean index: one line per component (+ the blocks catalog).
      def index
        lines = @registry.entries.map do |path, entry|
          "- #{title(path)}: `#{helper(path)}` - #{index_summary(entry)}"
        end
        "#{PREAMBLE}\n## Components\n\n#{lines.join("\n")}\n#{blocks_index}"
      end

      # The index line's summary: the human description leads (what it is),
      # then the style surface (its variants) in parens so an agent still sees
      # the options at a glance. Description-less entries fall back to the
      # surface alone.
      def index_summary(entry)
        surface = surface_summary(entry)
        return surface unless entry["description"]

        surface == "no style attributes" ? entry["description"] : "#{entry["description"]} (#{surface})"
      end

      # The full contracts: props, slots, elements, and agent rules - plus
      # every block's source, so an agent holding this file can start a
      # screen from a vetted composition without another fetch.
      def full
        sections = @registry.entries.map { |path, entry| component_section(path, entry) }
        "#{PREAMBLE}\n#{sections.join("\n")}#{forms_full}#{blocks_full}"
      end

      # The Forms section (the registry's optional form_builder surface):
      # the model-bound builder rules + method table, so an agent writing a
      # form reaches for f.input before hand-composing Fields.
      def forms_full
        surface = @registry.respond_to?(:form_builder) ? @registry.form_builder : nil
        return "" unless surface&.any?

        lines = ["\n## Forms (Poetry::Ui::FormBuilder)\n"]
        Array(surface["rules"]).each { |rule| lines << "- #{rule}" }
        if (methods = surface["methods"])&.any?
          lines << "\nBuilder methods:"
          methods.each { |name, summary| lines << "- `f.#{name}` - #{summary}" }
        end
        if (types = surface["input_types"])&.any?
          lines << "\n`f.input as:` values: #{types.join(", ")}."
        end
        "#{lines.join("\n")}\n"
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
        lines << "#{entry["description"]}\n" if entry["description"]
        lines << "Class: #{entry["class_name"]} - BEM block `#{entry["bem_block"]}`."
        if (hint = entry["requires_content"])
          lines << "Content block REQUIRED (#{hint}) - a blockless call raises."
        end
        (entry["required_slots"] || {}).each do |setter, hint|
          lines << "Slot REQUIRED: with_#{setter} (#{hint}) - a call without it raises."
        end
        (entry["requires_any"] || []).each do |group|
          lines << "REQUIRED - #{any_of_phrase(group)}; a call satisfying none raises."
        end
        lines.concat(prop_lines(entry))
        slots = entry["slots"].map { |slot| slot_summary(slot) }
        lines << "Slots: #{slots.join(", ")}." if slots.any?
        lines.concat(part_lines(entry))
        # The block back-reference: the arrow points UP at the
        # surface agents actually read - a screen containing this component
        # should start from the vetted composition, not from scratch.
        if (blocks = blocks_composing(title(path))).any?
          lines << "In blocks: #{blocks.join(", ")} - for a screen, start from the block " \
                   "(MCP compose/describe_block, or `bin/rails g poetry:block`), not from scratch."
        end
        lines.concat(wiring_lines(entry))
        (entry["agent_rules"] || []).each { |rule| lines << "- RULE: #{rule}" }
        "#{lines.join("\n")}\n"
      end

      # The styling contract: every data-slot part with its state
      # attributes and var seams - DOM-verified by the part-contract tier,
      # so a restyling instruction can only target selectors that provably
      # exist. Restyle via `[data-slot=<part>]` (+ state selectors); never
      # guess at internal markup.
      def part_lines(entry)
        (entry["parts"] || []).map do |part|
          facets = []
          states = (part["states"] || []).map { |state| state_phrase(state) }
          facets << "states: #{states.join("; ")}" if states.any?
          vars = (part["vars"] || []).map { |var| "#{var["name"]} (#{var["description"]})" }
          facets << "vars: #{vars.join("; ")}" if vars.any?
          "- PART `#{part["name"]}` - #{part["description"]}#{" | #{facets.join(" | ")}" if facets.any?}"
        end
      end

      def state_phrase(state)
        values = state["values"] ? "=#{state["values"].join("|")}" : ""
        "#{state["attr"]}#{values} (#{state["condition"]})"
      end

      # The any-of contract, phrased once: "one of a content block
      # / with_leading / loading: (hint)".
      def any_of_phrase(group)
        parts = []
        parts << "a content block" if group["content"]
        parts.concat((group["slots"] || []).map { |name| "with_#{name}" })
        parts.concat((group["options"] || []).map { |key| "#{key}:" })
        "one of #{parts.join(" / ")} (#{group["hint"]})"
      end

      # Block names composing a component (inverted from the blocks
      # catalog), or [] for a registry without blocks.
      def blocks_composing(component_title)
        @blocks_composing ||= (@registry.blocks || {}).each_with_object(Hash.new do |h, k|
          h[k] = []
        end) do |(name, entry), map|
          entry["components"].each { |component| map[component] << "`#{name}`" }
        end
        @blocks_composing[component_title]
      end

      # The Stimulus wiring surface: the controllers a component
      # renders, each with the targets / values / actions an agent may wire
      # by hand and the events it may listen for.
      # Absent for static components.
      # Element-level when the entry carries the projection (use_stimulus
      # declarations); the controller-level capability view otherwise
      # (charts, external registries).
      def wiring_lines(entry)
        return element_wiring_lines(entry) if entry["stimulus"]

        (entry["controllers"] || []).map do |controller|
          facets = []
          facets << "targets #{controller["targets"].join(", ")}" if controller["targets"].any?
          facets << "values #{controller["values"].join(", ")}" if controller["values"].any?
          facets << "actions #{controller["actions"].join(", ")}" if controller["actions"].any?
          facets << "events #{controller["events"].join(", ")}" if (controller["events"] || []).any?
          "- WIRING `#{controller["identifier"]}`#{": #{facets.join("; ")}" unless facets.empty?}"
        end
      end

      def element_wiring_lines(entry)
        entry["stimulus"].map do |element|
          phrases = element["controllers"].map { |wiring| wiring_phrase(wiring) }
          suffix = element["conditional"] ? " (#{element["conditional"]})" : ""
          "- WIRING #{element["element"]}#{suffix}: #{phrases.join(" | ")}"
        end
      end

      def wiring_phrase(wiring)
        facets = []
        facets << "registers#{" (#{wiring["registers"]})" unless wiring["registers"] == true}" if wiring["registers"]
        if (values = wiring["values"])
          facets << "values #{values.map { |value| conditional_name(value, "name") }.join(", ")}"
        end
        if (actions = wiring["actions"])
          facets << "actions #{actions.map { |action| action_phrase(action) }.join(", ")}"
        end
        if (targets = wiring["targets"])
          facets << "targets #{targets.map { |target| conditional_name(target, "name") }.join(", ")}"
        end
        suffix = wiring["conditional"] ? " (#{wiring["conditional"]})" : ""
        "`#{wiring["identifier"]}`#{suffix} #{facets.join("; ")}".strip
      end

      def action_phrase(action)
        phrase = action["method"]
        if (on = action["on"])
          events = Array(on).join("/")
          events = "#{events}@#{action["at"]}" if action["at"]
          phrase = "#{phrase} on #{events}"
        end
        action["conditional"] ? "#{phrase} (#{action["conditional"]})" : phrase
      end

      def conditional_name(item, key)
        item["conditional"] ? "#{item[key]} (#{item["conditional"]})" : item[key]
      end

      def prop_lines(entry)
        (entry["styles"] + entry["options"]).map do |prop|
          details = []
          details << "one of #{prop["variants"].join("|")}" if prop["variants"]
          details << "default #{prop["default"].inspect}" if prop.key?("default")
          details << "required" if prop["required"]
          details << "format: #{prop["format"]}" if prop["format"]
          line = "- `#{prop["name"]}:` (#{prop["type"]})#{" - #{details.join(", ")}" if details.any?}"
          prop["description"] ? "#{line} - #{prop["description"]}" : line
        end
      end

      # A typed slot renders another component: the call takes THAT
      # component's props, never a render block (with_icon(name: ...) - the
      # block-form guess an agent would otherwise make, which this line now
      # forecloses). Untyped slots take blocks; many-slots say so; a
      # polymorphic slot lists its with_<type> setters - and when they are
      # all kwargs-only, says so (foreclosing the type-as-argument
      # dispatch no setter has). Each shape that raises at render
      # gets its own sentence: yieldless setters (no |param| - it would be
      # nil), closed keyword signatures (the exact accepted set), and
      # setters that cannot omit their content block.
      def slot_summary(slot)
        qualifiers = []
        qualifiers << slot["description"] if slot["description"]
        qualifiers << "many" if slot["many"]
        if slot["types"]
          convention = kwargs_only_setters?(slot) ? " - one with_<type> setter each, options as keywords" : ""
          qualifiers << "types #{slot["types"].join("|")}#{convention}"
        end
        qualifiers << "takes #{helper(slot["component"])} props, not a block" if slot["component"]
        if (yieldless = slot["yieldless"])
          setters = yieldless.map { |name| "with_#{name}" }.join("/")
          verb = yieldless.size == 1 ? "yields" : "yield"
          qualifiers << "#{setters} #{verb} NOTHING to the block - no |param|, write content directly"
        end
        (slot["setter_kwargs"] || {}).each do |setter, keywords|
          qualifiers << "with_#{setter} keywords: #{keywords.map { |keyword| "#{keyword}:" }.join(", ")} ONLY"
        end
        (slot["required_content"] || {}).each do |setter, hint|
          qualifiers << "with_#{setter} REQUIRES a content block (#{hint})"
        end
        # The nested requirement seam (with_menu
        # without with_trigger raises - stated where agents read).
        (slot["builders"] || {}).each do |setter, surface|
          (surface["required_slots"] || {}).each do |required, hint|
            qualifiers << "each with_#{setter} REQUIRES with_#{required} inside its block (#{hint})"
          end
        end
        "#{slot["name"]}#{" (#{qualifiers.join("; ")})" if qualifiers.any?}"
      end

      def kwargs_only_setters?(slot)
        args = slot["setter_args"]
        # A type with no tracked arity (rest-signature) is unknowable - the
        # claim only holds when every setter is known kwargs-only.
        args && slot["types"].all? { |type| args[type]&.zero? }
      end

      # The blocks catalog: vetted composed screens, one
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

          Blocks are the DEFAULT starting point, not a fallback: route every
          brief through the MCP `compose` tool first - it returns the
          matching block's source ready to adapt, or the component path when
          nothing matches. Without MCP: `bin/rails g poetry:block <name>`
          copies a block into app/views/blocks/ as source the app owns
          (--list to browse). Blocks carry the composed patterns -
          containment, status color-coding, page furniture, realistic
          content - so a screen starts composed, not blank. Page framing
          counts: a section that IS the page's subject keeps its container +
          breathing room (the section blocks demonstrate the wrapper) - a
          bare component at the viewport origin reads cramped.

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
