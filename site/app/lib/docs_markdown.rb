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

        `bin/rails g poetry:editor` wires Poetry's MCP server and registry-driven snippets into VS Code, Cursor, Claude Code, Zed, and RubyMine: safe MCP-config upserts (`.mcp.json`: command `bundle`, args `["exec", "poetry-agent"]`), per-editor snippet formats, and the Figma / Paper design-tool token bridges. The MCP server serves ten tools from the live registry with no app boot - `compose`, `build_page`, `list_components`, `describe_component`, `check`, `list_blocks`, `describe_block`, `list_recipes`, `get_skill`, and `guidance`.
      MD
    end

    def testing(entry)
      <<~MD
        #{header(entry)}

        Poetry apps test at the cheapest tier that can catch the bug, so a failing test names the fix. Lint first: `bin/rails poetry:check` validates ERB against the component registry and controllers manifest without rendering (`POETRY_CHECK_JSON=1` for CI, `POETRY_CHECK_DESIGN=1` adds design warnings). Wiring tests render a view and assert `data-slot` parts, ARIA, form participants, and Stimulus wiring, never Tailwind classes. For real interaction, `include Poetry::Ui::Testing` in a system test: `poetry_select`, `poetry_combobox`, `poetry_dropdown_menu`, and `poetry_dialog` drive components through real keyboard and pointer sequences (`via: :keyboard` or `:mouse`) and assert the public attribute contract. Refresh the safelist before any browser pass.
      MD
    end

    def accessibility(entry)
      <<~MD
        #{header(entry)}

        Poetry guarantees a floor by construction: dialogs will not render without an accessible name, the field chain wires `aria-describedby` and `aria-invalid`, form components serialize through real native controls, overlays ride the native dialog element for focus trapping and return, and the token importer drops swatches failing WCAG AA. Automated scanners catch roughly a third of WCAG issues, so verify your app manually: VoiceOver or NVDA, keyboard only, light and dark, 200% zoom, reduced motion on - the page carries a universal checklist plus per-pattern checklists for forms, overlays, menus, navigation, data, and streaming surfaces. In CI, run `bin/rails poetry:check` and an axe scan (WCAG 2.0 A and AA) against key pages per shipped theme.
      MD
    end

    def caching(entry)
      <<~MD
        #{header(entry)}

        Rails template digests cannot see Poetry - helpers are never discovered as dependencies and gem templates resolve outside the host's view paths - so an unkeyed cached fragment silently serves stale UI across component upgrades. The recipe: version-keyed cache keys (`cache [@post, Poetry::Ui::VERSION]`; `Poetry::Charts::VERSION` for charts) so each upgrade misses once. Components inside a cache block take `key:` or `id:` so replayed HTML never collides or defeats morph pairing; `poetry:check` warns (`stable-identity/cache`) and `poetry_id_integrity_script` audits the composed page. Copy-ins add `Template Dependency` comments; keep CSRF-bearing form tags outside cached fragments.
      MD
    end

    def engines(entry)
      <<~MD
        #{header(entry)}

        The recipe: the engine declares `spec.add_dependency "poetry-ui"`, renders in the host's chrome (`layout "application"` - in an isolated engine the bare name resolves to the host's layout), and composes views from the helpers, shipping no CSS, tokens, or theme. Helpers and Stimulus registration are host-global, and the host safelist emits every component class without scanning gems, so engine markup renders styled with zero build integration. The one wiring step covers the engine's own page-level utilities: the engine ships `app/assets/tailwind/<engine_name>/engine.css` containing `@source "../../../views";`, the host runs `bin/rails tailwindcss:engines` and adds `@import "../builds/tailwind/<engine_name>";`. Retheme = `bin/rails g poetry:install --theme <name>` + a CSS rebuild in the host; every mounted engine follows. Component customization is the subclass pair (`Billing::StatusAlert::Component < Poetry::Ui::Alert::Component` with sibling `Style` - the dictionary copies down and extends); there is no per-render style-class parameter. Doctrine: engines never ship visual CSS - one theme contract is what keeps the one-command retheme true across engines.
      MD
    end

    def stable_ids(entry)
      <<~MD
        #{header(entry)}

        Poetry components mint DOM ids for ARIA and pairing wiring by a precedence ladder: explicit `id:` (internals derive as `<id>-trigger` and friends), semantic `key:` (records via `dom_id`), form-builder ids, then a random per-render fallback that deliberately over-replaces under a Turbo morph. Identity is mandatory in collections, fragment-cache blocks, morph-destined broadcast partials, and repeated new-record forms. `poetry:check` warns statically; `poetry_id_integrity_script` scans the composed page for duplicates after every load, morph, and stream insertion. Override `to_key`/`to_param` to keep primary keys out of the DOM; an opt-in sequence mode gives byte-stable pages with documented hazards.
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

        Poetry's agent surface is a standard stdio MCP server, `bundle exec poetry-agent`: boot-free (it reads the committed registry, never boots Rails) and read-only by design. Its ten tools close a verify loop: `compose` routes any brief to a vetted block or the matching components, `build_page` runs a five-step guided workflow for whole screens, `list_components`/`describe_component` disclose contracts at `brief|detailed|full` depth, and `check` returns a line-numbered PASS/FAIL verdict - the same linter as `bin/rails poetry:check`. `list_blocks`/`describe_block` serve the composed-screen catalog with full ERB source, `list_recipes` surfaces the multi-file payloads, and `get_skill`/`guidance` serve the installed skill text at runtime. The same registry projects `/poetry/llms.txt` and `/poetry/llms-full.txt`, so no surface can drift. Editor configuration lives on the Editors page.
      MD
    end

    # The Core library page's mirror.
    def library_core(entry)
      <<~MD
        #{header(entry)}

        poetry-core is the engine gem: subclass `Poetry::Core::Component` and declare the whole public surface at class level - `style :variant, default:, variants:, doc:` for visual axes (closed vocabularies become inclusion validations and registry facts), `option :count, :integer` for typed attributes, `renders_one`/`renders_many` slots documented with `slot_doc`, `part` for the DOM-verified anatomy contract, and `use_stimulus` to wire the 53 shipped Stimulus behavior controllers, validated against the controllers manifest at class load. A sidecar `Style` dictionary (`base`/`element`/`variant`/`compound`) maps style values to CSS classes; `css_mode :tailwind` (default) resolves Tailwind utilities through a conflict-aware merger, while `css_mode :bem` emits a stable derived class vocabulary (`my-kit-pill--variant-danger`) for bring-your-own-CSS hosts, styled against a `Poetry::Core::CSS::BemReference` skeleton whose capsule digest detects dictionary drift. Design tokens generate from one DTCG source into contrast-gated CSS custom properties, `Poetry::Core::Registry` builds the committed machine-readable index from introspection, and `Poetry::Core::Check` lints consumer ERB against it statically (`bin/rails poetry:check`, the MCP `check` tool).
      MD
    end

    # The UI library page's mirror.
    def library_ui(entry)
      <<~MD
        #{header(entry)}

        poetry-ui is the component catalog: 87 shadcn-parity components rendered server-side through 140 `poetry_*` helpers (composites yield `with_*` slot builders), installed by the idempotent `bin/rails g poetry:install --theme <name>` and indexed by the committed registry at `config/component_registry.yml`. Nine complete themes ship in the gem (default, vega, nova, mira, rhea, maia, luma, lyra, sera); switching restyles the whole catalog. Model-bound forms hand off to `form_with(model:, builder: Poetry::Ui::FormBuilder)` - `f.input` infers the component from the attribute type, `f.association` reflects associations. Components are gem-owned until you want them: `bin/rails g poetry:add button` copies source into `app/components` where autoload precedence shadows the gem (never overwritten; `poetry:diff` reports drift; remote registry addresses install too). Eight blocks (app-shell, data-index, page-header, section-card, destructive-panel, stepper, action-bar, top-nav) and multi-file recipes sit above the components. The agent surface: `/poetry/llms.txt`, the ten-tool MCP server (`bundle exec poetry-agent`), the poetry/poetry-design/poetry-component skills, and `bin/rails poetry:check`. `include Poetry::Ui::Testing` drives Select, Combobox, Dropdown menu, and Dialog through real keyboard/pointer contracts in system tests.
      MD
    end

    def library_charts(entry)
      <<~MD
        #{header(entry)}

        poetry-charts computes chart geometry in Ruby - data to domains, scales, ticks, and paths - and ships the finished chart as SVG in the initial HTML, so charts stay valid with JavaScript disabled, in print, PDF, and email. Nine families ship in the gallery: area, bar, line, pie, radar, radial bar, scatter, and composed, plus the adapter mount; `poetry_area_chart`, `poetry_line_chart`, and `poetry_bar_chart` are dedicated helpers and `poetry_chart(:pie, ...)` dispatches every family, composed from slots (`with_grid`, `with_x_axis`, `with_area`, `with_tooltip`, `with_legend`). Install with `gem "poetry-charts"` plus `bin/rails g poetry:install --charts`. The cartesian trio takes `live: true` for data that cannot round-trip: the chart embeds its spec plus a client renderer proven byte-equal to the Ruby engine and redraws in place, and live mode unlocks the client-side brush and zoom window. Every chart also compiles to a frozen chart-spec v1; `engine:` routes the same call to a registered adapter (`series:`/`axes:` arguments instead of slots) for bring-your-own engines. Colors ride the theme's `--chart-1` through `--chart-5` ramp with a per-series `--color-<key>` variable, so theme and dark-mode flips restyle every chart with zero re-render.
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

        The discovery index at [/.well-known/agent-skills/index.json](/.well-known/agent-skills/index.json) (agentskills.io discovery schema 0.2.0) lists every skill with a payload url and a `sha256:` digest a conformant installer verifies before writing anything. In a Rails app with Poetry, `bin/rails g poetry:skill` installs the poetry, poetry-design, and poetry-component skills without touching the network.
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

        This page embeds page-agent v1.12.2 (MIT, vendored) configured with Poetry's OPERATOR REGISTER - the component contract in GUI-operator vocabulary: `includeAttributes: ["data-component", "data-slot"]` plus per-page instructions served at [/operator-register.json](/operator-register.json). Nothing loads until a visitor activates it (bring-your-own OpenAI-compatible key, session-only). The task list on the page carries pre-registered, measured expectations: each task is pre-classified as ARIA-alone / register-helps / expected-failure-on-the-agent's-input-layer (keyboard-first components cannot be driven by synthetic clicks).
      MD
    end

    # The Simple Form library page's mirror.
    def library_simple_form(entry)
      <<~MD
        #{header(entry)}

        The migration bridge from Simple Form: `bin/rails g poetry:simple_form:install` writes one initializer (`Poetry::SimpleForm.activate!`) that re-maps the input types onto classes rendering whole Poetry fields through `Poetry::Ui::FormBuilder`, so existing `f.input` calls keep working with label, hint, error, and aria derived from the model on the same path the native builder uses. `f.association` works unchanged, `:datetime` falls back to stock Simple Form rendering, and `simple_form.*` i18n keys keep resolving as a fallback chain. Simple Form contributes only type resolution; its wrapper tree is bypassed by design. Delete the initializer to restore stock rendering instantly; the end state is `form_with(model:, builder: Poetry::Ui::FormBuilder)` per the [form builder guide](/forms).
      MD
    end

    # The Extract library page's mirror.
    def library_extract(entry)
      <<~MD
        #{header(entry)}

        Domain in, theme out: `bin/rails "poetry:design:extract[stripe.com]"` writes `DESIGN.md` (YAML frontmatter tokens over a Markdown body), `theme.tailwind.css` (a complete Tailwind v4 stylesheet), and `tokens.css` (plain `:root`/`.dark` custom properties) under `tmp/poetry/design_extract/<domain>/`, all in Poetry's token vocabulary. Fetch rides context.dev (`CONTEXT_DEV_API_KEY`; without a key it degrades to a homepage-only fetch), one Claude call composes the DESIGN.md (`ANTHROPIC_API_KEY`; `POETRY_EXTRACT_MODEL` overrides the model), and the token stylesheets are derived deterministically from the fetched styleguide and brand - same inputs, same bytes, no model output in them. Nothing touches your theme: the printed `bin/rails "poetry:design:import[...]"` runs Poetry's existing importer, which drops any swatch failing WCAG AA.
      MD
    end

    # The Lucide icon-set page's mirror.
    def icons_lucide(entry)
      <<~MD
        #{header(entry)}

        The default icon set: 1,745 Lucide icons vendored into the gem at a pinned upstream commit (`Poetry::Lucide.vendored_commit`) and sanitized at vendor time, so rendering never parses, never sanitizes, and never touches the network. Requiring the gem registers the set as `:lucide`; `poetry_icon(name: :"circle-check")` renders decorative (aria-hidden) by default, and `label:` makes an icon standalone (`role="img"` plus the accessible name). `poetry check` validates icon-name literals statically against the set; a dynamic miss raises with a did-you-mean in development and test and renders the configured fallback (`:"circle-question-mark"`) in production while `on_missing_icon` fires. The vendored Lucide icons remain under Lucide's ISC license - see `LICENSE-LUCIDE.txt`, which ships in the gem beside them.
      MD
    end

    # The root llms.txt: the whole site, indexed for agents - every docs
    # page with its one-liner, plus the machine-readable resources.
    def site_index
      out = [ <<~MD ]
        # poetry docs

        > The documentation site for Poetry, an AI-native, Rails-first component library: accessible, themeable ViewComponents on semantic design tokens. Every page below also serves a markdown mirror - append `.md` to its URL or send `Accept: text/markdown`.
      MD
      { "Guides" => DocsCatalog.docs, "Libraries" => DocsCatalog.libraries,
        "Icons" => DocsCatalog.icons, "Components" => DocsCatalog.components,
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
