# frozen_string_literal: true

module Poetry
  module Core
    # Generates the component-usage Claude Code skill from the registry
    # (Skills v1) - the same never-hand-maintained discipline as
    # LlmsText, one delivery surface over: a lean SKILL.md menu (guardrails
    # + family index) over references/ files an agent loads selectively,
    # so a 65-component catalog stays inside the context budget.
    # The family partition itself belongs to the UI gem (it knows its
    # roster); this class only formats.
    class SkillText < LlmsText
      def initialize(registry:, families:, charts_registry: nil)
        super(registry: registry)
        @families = families
        @charts_registry = charts_registry
      end

      # The installable file map, paths relative to .claude/skills/poetry/.
      def files
        files = { "SKILL.md" => skill_md }
        @families.each_key { |family| files["references/#{family}.md"] = family_reference(family) }
        files["references/blocks.md"] = blocks_reference
        files["references/charts.md"] = charts_reference if @charts_registry
        files
      end

      # Contract sections for every entry, llms-full format - public here
      # (unlike LlmsText's internals) so a charts-registry instance can
      # lend its sections to the main skill's charts reference.
      def sections(paths = nil)
        entries = paths ? @registry.entries.slice(*paths) : @registry.entries
        entries.map { |path, entry| component_section(path, entry) }.join("\n")
      end

      private

      def skill_md
        <<~MD
          ---
          name: poetry
          description: >-
            Build Rails views with the poetry component library: helper
            contracts, options, slots, blocks, and the check workflow. Use
            whenever writing or editing ERB/UI in an app that has poetry
            installed.
          ---

          # poetry - component usage

          Generated from the poetry registry (#{census}). After updating
          poetry gems, regenerate with `bin/rails g poetry:skill`.

          ## Guardrails

          - Compose with the `poetry_<name>` helpers; never hand-write `cn-*`
            classes, raw hex/oklch colors, or off-scale arbitrary values -
            tokens and variants carry the design.
          - Starting a new SCREEN? Begin from a vetted block
            (`references/blocks.md`, or `bin/rails g poetry:block --list`) and
            edit it in place; compose atoms only for what no block covers.
          - Options are keywords; content is the block. Helpers take at most
            the positional arguments their contract lists - most take none.
          - A typed slot renders another component: the call takes THAT
            component's props, never a render block.
          - Icon names are kebab-case symbols: `:"circle-check"`, never
            `:circle_check`.
          - Status reads as a set: one badge treatment family per surface -
            never mix solid (default/destructive) and soft
            (success/warning/info) pills in one table.
          - Page framing: a section that IS the page's subject keeps its
            container and breathing room (`mx-auto max-w-* p-6`); a bare
            component at the viewport origin reads cramped. Drop the wrapper
            when composing into an already-padded frame.
          - One visual theme per app (chosen at install); components read
            tokens, never restate them.
          - Check comes LAST: run `bin/rails poetry:check` (or the poetry MCP
            `check` tool - instant, no app boot) as the FINAL action, after
            your last edit. An edit made after your last check is unverified
            markup - re-run check before finishing, every time.

          ## Find your component

          Load the reference for the family you are composing in - each file
          carries the full contracts (options, variants, slots, wiring, RULE
          lines) for its components:

          #{family_index}

          ## Composing a page? Load poetry-design

          Building or restyling a full page, screen, or dashboard - not a
          lone component? Load the `poetry-design` skill BEFORE composing:
          theme fit, page macrostructure, hierarchy, status color, and the
          finishing audit live there. Component contracts alone do not make
          a composed page.
        MD
      end

      def census
        parts = ["#{@registry.entries.size} components"]
        parts << "#{@charts_registry.entries.size} chart components" if @charts_registry
        blocks = @registry.blocks
        parts << "#{blocks.size} blocks" if blocks&.any?
        parts.join(" + ")
      end

      def family_index
        lines = @families.map do |family, members|
          "- **#{family}** (`references/#{family}.md`): #{members.join(", ")}"
        end
        lines << "- **blocks** (`references/blocks.md`): #{(@registry.blocks || {}).keys.join(", ")}"
        lines << "- **charts** (`references/charts.md`): #{chart_names.join(", ")}" if @charts_registry
        lines.join("\n")
      end

      def chart_names
        @charts_registry.entries.keys.map { |path| path.split("/").drop(2).join("_") }
      end

      def family_reference(family)
        members = @families.fetch(family)
        paths = @registry.entries.keys.select do |path|
          members.include?(path.split("/").drop(2).join("_"))
        end
        <<~MD
          # poetry #{family} components

          Contracts generated from the registry. `RULE` lines are constraints,
          not suggestions. Options are keywords; content is the block.

          #{sections(paths)}
        MD
      end

      # The blocks reference inlines every block's full source (the
      # lesson: the block WITH source is the load-bearing agent path).
      def blocks_reference
        <<~MD
          # poetry blocks - vetted composed screens

          Start a SCREEN from a block, then edit it in place:
          `bin/rails g poetry:block <name>` copies it into app/views/blocks/
          as source the app owns. Blocks carry the composed patterns -
          containment, status color-coding, page furniture, realistic
          content - so a screen starts composed, not blank. The sample
          content is meant to be replaced.
          #{blocks_full}
        MD
      end

      def charts_reference
        charts = self.class.new(registry: @charts_registry, families: {})
        <<~MD
          # poetry chart components

          Contracts generated from the charts registry. Chart data is
          server-rendered; the `poetry_chart(type, ...)` shorthand takes the
          chart type as its one positional argument.

          #{charts.sections}
        MD
      end
    end
  end
end
