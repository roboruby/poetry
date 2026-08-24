# frozen_string_literal: true

require "yaml"

module Poetry
  # Namespace for poetry's Rails generators and their shared step
  # modules.
  module Generators
    # The host-facing AGENTS.md section: a short, registry-derived
    # pointer layer for coding agents working in the host app - llms.txt
    # stays the catalog, this is the front door to it. Marker-bounded so a
    # re-run refreshes poetry's section without touching anything the host
    # wrote around it.
    #
    # Shared by poetry:install and the standalone poetry:agents (which
    # exists so hosts that must NOT re-run install - e.g. a docs app with a
    # hand-scoped style registry - can still refresh the pointer). NOTE:
    # Thor only registers methods added directly on the generator class as
    # steps, so each generator declares its own public step and calls
    # apply_agents_section.
    #
    # @api private
    module AgentsSection
      BEGIN_MARKER = "<!-- poetry:agents:begin -->"
      END_MARKER = "<!-- poetry:agents:end -->"

      # Writes or refreshes the marker-bounded poetry section in the
      # host's AGENTS.md.
      def apply_agents_section
        path = File.join(destination_root, "AGENTS.md")
        if File.exist?(path) && File.read(path).include?(BEGIN_MARKER)
          gsub_file "AGENTS.md",
                    /#{Regexp.escape(BEGIN_MARKER)}.*#{Regexp.escape(END_MARKER)}/mo,
                    agents_section.chomp
        elsif File.exist?(path)
          append_to_file "AGENTS.md", "\n#{agents_section}"
        else
          create_file "AGENTS.md", agents_section
        end
      end

      # The marker-bounded section text, registry-derived.
      def agents_section
        <<~MD
          #{BEGIN_MARKER}
          ## Building UI with poetry (#{agents_component_counts})

          - FIRST MOVE on any UI brief: call the poetry MCP `compose` tool with the
            task text, before writing any ERB. It routes to the matching vetted
            block (source included, adapt in place - the winning path for screens)
            or to the right components. No MCP? `bin/rails g poetry:block --list`
            and start from the closest block. Composing a screen from scratch when
            a block matched is the known losing path.
          - Compose with the `poetry_*` helpers; never hand-write `cn-*` classes, raw
            hex/oklch colors, or off-scale arbitrary values - tokens and variants carry
            the design.
          - Machine catalog: `/poetry/llms.txt` (index + blocks) and `/poetry/llms-full.txt`
            (full contracts + Stimulus wiring: targets / values / actions / events).
          - Check comes LAST: `bin/rails poetry:check` as the FINAL action, after
            the last edit (unknown components/slots/variants/wiring, icon names,
            enum values, typed-slot props, helper + setter arity, yield-less
            blocks, setter keywords, required content blocks, required slots,
            did-you-mean, `--json`; needs the `herb` gem in the Gemfile). An edit
            made after your last check is unverified markup - re-run it.
          - Faster: the `poetry` MCP server (`.mcp.json`: command `bundle`, args
            `["exec", "poetry-agent"]`) serves nine tools from the live registry
            with no app boot - `compose`, `build_page`, `list_components`,
            `describe_component`, `check`, `list_blocks`, `describe_block`,
            `get_skill`, and `guidance`. Prefer `compose` (or `build_page` for a
            whole screen) to start, and its `check` tool when iterating. Wire it
            into every editor at once with `bin/rails g poetry:editor` (MCP
            configs for VS Code / Cursor / Claude Code / Zed / RubyMine plus
            registry-driven snippets).
          - One visual theme per app (chosen at install with `--theme`); components
            read tokens, never restate them.
          - Component identity: pass `key:` (a record, or a literal string) on any
            poetry component inside a collection loop, a fragment-cache block, or
            a broadcast partial - keyed ids follow the record across Turbo morph
            reorders and stay stable inside cached fragments, where random ids
            force replacement. `key: record` derives via dom_id (a host `to_key`
            override propagates); explicit `id:` wins outright; repeated NEW
            records need explicit keys. `poetry:check` warns on unkeyed
            components in cache blocks and loops. Full story: docs/stable-ids.md.
          - Upgrading poetry gems: after `bundle update`, re-run
            `bin/rails g poetry:install` - the vendored token/theme/safelist
            files refresh (the installed theme sticks; `--theme` switches),
            new wiring appends, this section and the skills regenerate. Then
            rebuild CSS and run the suite. `bin/rails g poetry:diff` reports
            where copied-in components drift from the installed gems.
          - `bin/rails g poetry:scaffold_templates` retargets the STANDARD
            `rails g scaffold` to emit poetry-composed views (DataTable index
            with URL state, Field-composed forms) plus a matching controller -
            prefer scaffolding over hand-writing CRUD views.
          - Claude Code skills: `poetry` (component contracts by family),
            `poetry-design` (theme / compose / audit / study / figma / paper -
            the taste layer), and `poetry-component` (anatomy / documentation /
            audit - the authoring layer) live under `.claude/skills/` - load
            `poetry` whenever writing ERB, `poetry-design` whenever composing a
            page or screen, BEFORE building (any page task is a design task,
            not only ones that mention design), and `poetry-component` whenever
            authoring or reviewing an app-owned component. Install/refresh:
            `bin/rails g poetry:skill`.
          - Design interop: `bin/rails poetry:design:export` writes this app's
            DESIGN.md (tokens + treatment) for external design skills.
          - Overriding the theme: token-level restyling goes through
            `poetry:design:import` (design-overrides.css) - which also ingests a
            Figma variables export (`bin/rails poetry:figma:import[export.json]`)
            or a Paper "Copy theme" (`bin/rails poetry:paper:import[theme.css]`),
            dropping any swatch that fails WCAG AA. Host CSS that targets
            theme-owned `cn-*` classes is allowed ONLY as a declared
            override - a dated, reasoned entry under `overrides:` in
            config/poetry_components.yml (`bin/rails poetry:design:overrides`
            reports drift and prints the paste-ready declaration). Declare
            only after the user confirms intent; never declare to skip a fix.
          #{END_MARKER}
        MD
      end

      # The human count line (components + charts + blocks) for the
      # section heading.
      def agents_component_counts
        parts = ["#{agents_registry_size(Poetry::Ui.root)} components"]
        # Tolerant on charts: a stubbed/partial gem without a registry file
        # (the install-test stub) just drops out of the count.
        charts = defined?(Poetry::Charts::Engine) && agents_registry_size(Poetry::Charts.root)
        parts << "#{charts} chart components" if charts
        blocks = agents_registry_size(Poetry::Ui.root, section: "blocks")
        parts << "#{blocks} blocks" if blocks&.positive?
        parts.join(" + ")
      end

      # One section's entry count from a gem's committed registry (nil
      # when the gem ships none).
      def agents_registry_size(root, section: "components")
        path = root.join("config/component_registry.yml")
        return nil unless File.exist?(path)

        (YAML.safe_load_file(path)[section] || {}).size
      end
    end
  end
end
