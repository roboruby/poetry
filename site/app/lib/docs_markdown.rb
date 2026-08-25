# frozen_string_literal: true

# Markdown mirrors for the docs pages (the append-.md contract, extended
# site-wide) plus the root llms.txt index. Everything composes from the
# same disk sources the HTML pages render - DocsCatalog entries, the
# example partials, the gem block templates - so the mirrors cannot say
# anything the site doesn't.
#
# @example A gallery page's markdown twin
#   DocsMarkdown.example_page(DocsCatalog.find("charts", "line"))
class DocsMarkdown
  class << self
    # The generic gallery mirror: header + install note + every example as
    # fenced ERB, read from the same partials the Preview/Code tabs render.
    def example_page(entry)
      sections = [ header(entry), install_note(entry) ]
      examples_for(entry).each do |name, source|
        sections << "## #{name.tr('_', ' ').capitalize}\n\n```erb\n#{source}\n```"
      end
      sections.compact.join("\n\n") + "\n"
    end

    # The block mirror: what `describe_block` returns and `poetry:block`
    # copies in - the exact gem template plus its composition roster.
    def block(entry)
      meta = DocsCatalog.block_meta(entry.slug)
      <<~MD
        #{header(entry)}

        Copy-in: `bin/rails g poetry:block #{entry.slug}` - the source below is exactly what the generator writes. Composes: #{meta.fetch('components').join(', ')}.

        ## Template

        ```erb
        #{block_source(meta)}
        ```
      MD
    end

    # The real gem template for a block, banner comment stripped - shared
    # by the HTML block page and the markdown mirror.
    def block_source(meta)
      Poetry::Ui.root.join(meta.fetch("template")).read
                .sub(/\A<%#\s*poetry:block[^%]*%>\n?/, "").strip
    end

    # The theming guide's mirror: prose plus the live theme roster read
    # from the gem, so a new theme appears here the moment it ships.
    def theming(entry)
      themes = Poetry::Ui.root.join("themes").glob("*.css").map { |f| f.basename(".css").to_s }.sort
      <<~MD
        #{header(entry)}

        Themes ship as complete visual fragments in poetry-ui (`themes/*.css`); an app runs exactly one, chosen at install time with `bin/rails g poetry:install --theme <name>` (re-runs are theme-sticky; `--theme` switches). Components read tokens and never restate them, so switching themes restyles the whole catalog.

        Available themes: #{themes.join(', ')}.

        Token-level restyling goes through `poetry:design:import` (design-overrides.css), which also ingests Figma variable exports and Paper themes and drops any swatch failing WCAG AA.
      MD
    end

    # The editors guide's mirror.
    def editors(entry)
      <<~MD
        #{header(entry)}

        `bin/rails g poetry:editor` wires poetry's MCP server and registry-driven snippets into VS Code, Cursor, Claude Code, Zed, and RubyMine: safe MCP-config upserts (`.mcp.json`: command `bundle`, args `["exec", "poetry-agent"]`), per-editor snippet formats, and the Figma / Paper design-tool token bridges. The MCP server serves ten tools from the live registry with no app boot - `compose`, `build_page`, `list_components`, `describe_component`, `check`, `list_blocks`, `describe_block`, `list_recipes`, `get_skill`, and `guidance`.
      MD
    end

    def testing(entry)
      <<~MD
        #{header(entry)}

        poetry apps test at the cheapest tier that can catch the bug, so a failing test names the fix. Lint first: `bin/rails poetry:check` validates ERB against the component registry and controllers manifest without rendering (`POETRY_CHECK_JSON=1` for CI, `POETRY_CHECK_DESIGN=1` adds design warnings). Wiring tests render a view and assert `data-slot` parts, ARIA, form participants, and Stimulus wiring, never Tailwind classes. For real interaction, `include Poetry::Ui::Testing` in a system test: `poetry_select`, `poetry_combobox`, `poetry_dropdown_menu`, and `poetry_dialog` drive components through real keyboard and pointer sequences (`via: :keyboard` or `:mouse`) and assert the public attribute contract. Refresh the safelist before any browser pass.
      MD
    end

    def accessibility(entry)
      <<~MD
        #{header(entry)}

        poetry guarantees a floor by construction: dialogs will not render without an accessible name, the field chain wires `aria-describedby` and `aria-invalid`, form components serialize through real native controls, overlays ride the native dialog element for focus trapping and return, and the token importer drops swatches failing WCAG AA. Automated scanners catch roughly a third of WCAG issues, so verify your app manually: VoiceOver or NVDA, keyboard only, light and dark, 200% zoom, reduced motion on - the page carries a universal checklist plus per-pattern checklists for forms, overlays, menus, navigation, data, and streaming surfaces. In CI, run `bin/rails poetry:check` and an axe scan (WCAG 2.0 A and AA) against key pages per shipped theme.
      MD
    end

    def caching(entry)
      <<~MD
        #{header(entry)}

        Rails template digests cannot see poetry - helpers are never discovered as dependencies and gem templates resolve outside the host's view paths - so an unkeyed cached fragment silently serves stale UI across component upgrades. The recipe: version-keyed cache keys (`cache [@post, Poetry::Ui::VERSION]`; `Poetry::Charts::VERSION` for charts) so each upgrade misses once. Components inside a cache block take `key:` or `id:` so replayed HTML never collides or defeats morph pairing; `poetry:check` warns (`stable-identity/cache`) and `poetry_id_integrity_script` audits the composed page. Copy-ins add `Template Dependency` comments; keep CSRF-bearing form tags outside cached fragments.
      MD
    end

    def stable_ids(entry)
      <<~MD
        #{header(entry)}

        poetry components mint DOM ids for ARIA and pairing wiring by a precedence ladder: explicit `id:` (internals derive as `<id>-trigger` and friends), semantic `key:` (records via `dom_id`), form-builder ids, then a random per-render fallback that deliberately over-replaces under a Turbo morph. Identity is mandatory in collections, fragment-cache blocks, morph-destined broadcast partials, and repeated new-record forms. `poetry:check` warns statically; `poetry_id_integrity_script` scans the composed page for duplicates after every load, morph, and stream insertion. Override `to_key`/`to_param` to keep primary keys out of the DOM; an opt-in sequence mode gives byte-stable pages with documented hazards.
      MD
    end

    def data_table(entry)
      <<~MD
        #{header(entry)}

        `Poetry::Ui::DataTable::State.from_params(params, sortable: %w[...])` sanitizes at the door - `sort` survives only the whitelist, `dir` only asc/desc - so `state.order_clause` is injection-safe by construction; the controller owns the scope and passes `total:` as a page count. In the view, `poetry_data_table(rows:, state:, total:, path:)` declares columns with `table.with_column("Title", key: :title, sortable: true) { |row| ... }`; a sortable key missing from the whitelist raises at render. `sticky_header: true` needs a `container_class:` height cap; `selectable:` adds a checkbox column posting `selected_ids[]`; `frame:` scopes Turbo round trips while the URL advances. Sort affordances are real links with `aria-sort`; the filter is a labelled GET form.
      MD
    end

    def mcp(entry)
      <<~MD
        #{header(entry)}

        poetry's agent surface is a standard stdio MCP server, `bundle exec poetry-agent`: boot-free (it reads the committed registry, never boots Rails) and read-only by design. Its ten tools close a verify loop: `compose` routes any brief to a vetted block or the matching components, `build_page` runs a five-step guided workflow for whole screens, `list_components`/`describe_component` disclose contracts at `brief|detailed|full` depth, and `check` returns a line-numbered PASS/FAIL verdict - the same linter as `bin/rails poetry:check`. `list_blocks`/`describe_block` serve the composed-screen catalog with full ERB source, `list_recipes` surfaces the multi-file payloads, and `get_skill`/`guidance` serve the installed skill text at runtime. The same registry projects `/poetry/llms.txt` and `/poetry/llms-full.txt`, so no surface can drift. Editor configuration lives on the Editors page.
      MD
    end

    # The recipes guide's mirror: the live projection, so the mirror lists
    # exactly what /r/ serves.
    def recipes(entry)
      sections = Poetry::Ui.recipe_items.summaries.map do |recipe|
        targets = recipe["files"].map { |file| "`#{file["target"]}`" }.join(", ")
        deps = recipe["registryDependencies"]
        <<~RECIPE.strip
          ## #{recipe["name"]}

          #{recipe["description"]}

          Install: `bin/rails g poetry:add #{recipe["name"]}` (or `npx shadcn@latest add @poetry/#{recipe["name"]}`). Files: #{targets}.#{deps.any? ? " Pulls blocks: #{deps.join(", ")}." : ""}
        RECIPE
      end
      ([ header(entry) ] + sections).join("\n\n") + "\n"
    end

    # The agent-skills catalog's mirror: the live projection, so the
    # mirror lists exactly what the discovery index serves. Commands carry
    # the requesting origin so they stay copy-pastable.
    def agent_skills(entry, base_url:)
      sections = SkillCatalog.sets.map do |name, files|
        <<~SKILL.strip
          ## #{name}

          #{SkillCatalog.description(files)}

          Files: #{files.keys.sort.map { |file| "`#{file}`" }.join(", ")}.

          Install: `npx skills add #{base_url}/agent-skills --skill #{name}` (add `-a <agent>` to target one of 70+ agents, `-g` for a global install). Dependency-free: `#{curl_command(name, files, base_url)}`.
        SKILL
      end
      intro = <<~MD.strip
        #{header(entry)}

        The discovery index at [/.well-known/agent-skills/index.json](/.well-known/agent-skills/index.json) (agentskills.io discovery schema 0.2.0) lists every skill with a payload url and a `sha256:` digest a conformant installer verifies before writing anything. In a Rails app with poetry, `bin/rails g poetry:skill` installs the poetry, poetry-design, and poetry-component skills without touching the network.
      MD
      ([ intro ] + sections).join("\n\n") + "\n"
    end

    # The dependency-free install one-liner: curl for a lone SKILL.md,
    # curl | tar for an archive payload.
    def curl_command(name, files, base_url)
      if SkillCatalog.single_file?(files)
        "curl -fsSL #{base_url}/agent-skills/#{name}/SKILL.md --create-dirs -o ~/.claude/skills/#{name}/SKILL.md"
      else
        "mkdir -p ~/.claude/skills/#{name} && curl -fsSL #{base_url}/agent-skills/#{name}.tar.gz | tar -xz -C ~/.claude/skills/#{name}"
      end
    end

    # The agent guide's mirror.
    def agent(entry)
      <<~MD
        #{header(entry)}

        This page embeds page-agent v1.12.2 (MIT, vendored) configured with poetry's OPERATOR REGISTER - the component contract in GUI-operator vocabulary: `includeAttributes: ["data-component", "data-slot"]` plus per-page instructions served at [/operator-register.json](/operator-register.json). Nothing loads until a visitor activates it (bring-your-own OpenAI-compatible key, session-only). The task list on the page carries pre-registered, measured expectations: each task is pre-classified as ARIA-alone / register-helps / expected-failure-on-the-agent's-input-layer (keyboard-first components cannot be driven by synthetic clicks).
      MD
    end

    # The root llms.txt: the whole site, indexed for agents - every docs
    # page with its one-liner, plus the machine-readable resources.
    def site_index
      out = [ <<~MD ]
        # poetry docs

        > The documentation site for poetry, an AI-native, Rails-first component library: accessible, themeable ViewComponents on semantic design tokens. Every page below also serves a markdown mirror - append `.md` to its URL or send `Accept: text/markdown`.
      MD
      { "Guides" => DocsCatalog.docs, "Components" => DocsCatalog.components,
        "Charts" => DocsCatalog.charts, "Blocks" => DocsCatalog.blocks,
        "Demos" => DocsCatalog.demos, "API" => DocsCatalog.apis }.each do |title, entries|
        out << "## #{title}\n\n" + entries.map { |e| "- [#{e.title}](#{e.path}): #{e.description}" }.join("\n")
      end
      out << <<~MD
        ## Machine-readable resources

        - [Component catalog for agents](/poetry/llms.txt) and [full contracts + Stimulus wiring](/poetry/llms-full.txt)
        - [Registry index](/r/registry.json) - shadcn-schema items; install with `bin/rails g poetry:add <name>` or `npx shadcn add`
        - [Agent skills inventory](/.well-known/skills/index.json) with per-file serving, and the [discovery index](/.well-known/agent-skills/index.json) (agentskills.io schema 0.2.0, sha256 digests) - `npx skills add <origin>/agent-skills` installs from it
        - [Agent install instructions](/installation.md)
        - [OpenAPI description](/openapi.json) and [API catalog](/.well-known/api-catalog)
      MD
      out.join("\n\n")
    end

    private

    def header(entry)
      [ "# #{entry.title}", entry.description ].compact.join("\n\n")
    end

    def install_note(entry)
      case entry.section
      when "components"
        "Included in poetry-ui as `poetry_#{entry.slug.tr('-', '_')}` with no per-component step. To own and edit the source: `bin/rails g poetry:add #{entry.slug}`."
      when "charts"
        "Ships in the separate, optional poetry-charts gem."
      end
    end

    # Same discovery + ordering as the HTML gallery (docs_examples_for):
    # the page's example partials, default first.
    def examples_for(entry)
      dir = Rails.root.join("app/views/examples/#{entry.section}/#{entry.slug}")
      return [] unless dir.exist?

      dir.glob("_*.html.erb")
         .map { |f| [ f.basename.to_s.delete_prefix("_").delete_suffix(".html.erb"), f.read.strip ] }
         .sort_by { |name, _| [ name == "default" ? 0 : 1, name ] }
    end
  end
end
