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
        return create_file("AGENTS.md", agents_section) unless File.exist?(path)

        text = File.read(path)
        return append_to_file("AGENTS.md", "\n#{agents_section}") unless text.include?(BEGIN_MARKER)

        # A begin marker needs its end, after it: anything else is a file
        # to fix by hand, never a silent rewrite of nothing.
        first = text.index(BEGIN_MARKER)
        last = text.index(END_MARKER, first)
        if last.nil?
          raise Thor::Error, "AGENTS.md has #{BEGIN_MARKER} without #{END_MARKER} after it - restore the markers, " \
                             "or delete the poetry section and re-run"
        end

        # The first section only (non-greedy), in the file's own line
        # endings; byte-identical is reported as such and left alone.
        newline = text.include?("\r\n") ? "\r\n" : "\n"
        section = agents_section.chomp.gsub("\n", newline)
        pattern = /#{Regexp.escape(BEGIN_MARKER)}.*?#{Regexp.escape(END_MARKER)}/m
        if text[pattern] == section
          say_status :identical, "AGENTS.md", :blue
        else
          gsub_file "AGENTS.md", pattern, section
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
          - Compose with the `poetry_*` helpers (and the app's own components through
            the helpers they declare with `helper :name`); never hand-write `cn-*`
            classes, raw hex/oklch colors, or off-scale arbitrary values - tokens and
            variants carry the design.
          - An app component written on the DSL declares `helper :name`; that makes it
            first-class on check, llms.txt and the skill. `bin/rails poetry:registry`
            (commit the file) exposes it to the MCP server too; `poetry:verify` fails
            when that file is stale. The app's own Stimulus controllers join the same
            way: `bin/rails poetry:stimulus:manifest` (commit the file) makes them
            validate like poetry's - `use_stimulus` by Symbol, template wiring in
            check, their API in the registry; generate the manifest BEFORE declaring
            a controller by Symbol (a Symbol not in the manifest fails at class load).
            A controller the reader cannot describe is named in the task output; an
            entry written by hand in the same file is kept across regenerations.
          - Machine catalog: `/poetry/llms.txt` (index + blocks) and `/poetry/llms-full.txt`
            (full contracts + Stimulus wiring: targets / values / actions / events).
          - Check comes LAST: `bin/rails poetry:check` as the FINAL action, after
            the last edit (unknown components/slots/variants/wiring, icon names,
            enum values, typed-slot props, helper + setter arity, yield-less
            blocks, setter keywords, required content blocks, required slots,
            did-you-mean, `POETRY_CHECK_JSON=1` for JSON; `poetry:install` adds the `herb` gem it parses with). An edit
            made after your last check is unverified markup - re-run it. Mailer
            templates (`*_mailer/`, the mailer layout) keep their inline colors:
            email has no tokens, so the raw-color rule is quiet there. Values that
            arrive from data meet a runtime tier: an off-list variant or a missing
            required option raises at construction in development and test.
          - Faster: the `poetry` MCP server (`.mcp.json`: command `bundle`, args
            `["exec", "poetry-agent"]`, the poetry-agent gem) serves ten tools from the live registry
            with no app boot - `compose`, `build_page`, `list_components`,
            `describe_component`, `check`, `list_blocks`, `describe_block`,
            `list_recipes`, `get_skill`, and `guidance`. Prefer `compose` (or `build_page` for a
            whole screen) to start, and its `check` tool when iterating. Wire it
            into every editor at once with `bin/rails g poetry:editor` (MCP
            configs for VS Code / Cursor / Claude Code / Zed / RubyMine plus
            registry-driven snippets).
          - Browser agents (WebMCP): opt a rendered component into the user's own
            agent with `webmcp: "name"` on the helper call - Combobox, Dialog, Sheet,
            Drawer, and Tabs declare tools (`describe_component` at `full` lists them);
            declare a form as a tool with `poetry_webmcp_form(tool: { name:,
            description: })` (autosubmit is GET-only). Needs the poetry-agent gem and
            `registerPoetryAgent(application)`; `poetry:check` gates the opt-ins.
          - One visual theme per app (chosen at install with `--theme`); components
            read tokens, never restate them.
          - Component identity: pass `key:` (a record, or a literal string) on any
            poetry component inside a collection loop, a fragment-cache block, or
            a broadcast partial - keyed ids follow the record across Turbo morph
            reorders and stay stable inside cached fragments, where random ids
            force replacement. `key: record` derives via dom_id (a host `to_key`
            override propagates); explicit `id:` wins outright; repeated NEW
            records need explicit keys. `poetry:check` warns on unkeyed
            components in cache blocks and loops. Full story: the Stable IDs guide on the poetry docs site.
          - Upgrading poetry gems: after `bundle update`, re-run
            `bin/rails g poetry:install` - the vendored token/theme/safelist
            files refresh (the installed theme sticks; `--theme` switches;
            never `--force`: the four host-owned seed files are left alone),
            new wiring appends, this section and the skills regenerate. Then
            rebuild CSS and run the suite. `bin/rails g poetry:diff` reports
            where copied-in components drift from the installed gems.
          - `bin/rails g poetry:scaffold_templates` retargets the STANDARD
            `rails g scaffold` to emit poetry-composed views (DataTable index
            with URL state, forms on the poetry form builder - one `f.input`
            per attribute) plus a matching controller - prefer scaffolding
            over hand-writing CRUD views.
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
            only after the user confirms intent; never declare to skip a fix. A
            kit's own `cn-*` classes are the app's, not overrides - prefix them
            (`cn-acme-*`) and never declare them.
          #{END_MARKER}
        MD
      end

      # The human count line (components + charts + blocks) for the
      # section heading.
      def agents_component_counts
        # Every published registry in the boot (no gem named; a stubbed gem
        # without a registry file simply contributes nothing), the app's
        # own committed registry counted apart.
        app_root = Rails.root.to_s
        gem_roots, app_roots = Poetry::Core::Registry.roots.partition { |root| root.to_s != app_root }
        parts = ["#{gem_roots.sum { |root| agents_registry_size(root).to_i }} components"]
        app = app_roots.sum { |root| agents_registry_size(root).to_i }
        parts << "#{app} app components" if app.positive?
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
