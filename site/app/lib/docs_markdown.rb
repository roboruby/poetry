# frozen_string_literal: true

# Markdown mirrors for the docs pages (the append-.md contract, extended
# site-wide) plus the root llms.txt index. Everything composes from the
# same disk sources the HTML pages render - DocsCatalog entries, the
# example partials, the gem block templates - so the mirrors cannot say
# anything the site doesn't.
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

        `bin/rails g poetry:editor` wires poetry's MCP server and registry-driven snippets into VS Code, Cursor, Claude Code, Zed, and RubyMine: safe MCP-config upserts (`.mcp.json`: command `bundle`, args `["exec", "poetry-agent"]`), per-editor snippet formats, and the Figma / Paper design-tool token bridges. The MCP server serves nine tools from the live registry with no app boot - `compose`, `build_page`, `list_components`, `describe_component`, `check`, `list_blocks`, `describe_block`, `get_skill`, and `guidance`.
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

    # The agent guide's mirror.
    def agent(entry)
      <<~MD
        #{header(entry)}

        This page embeds page-agent v1.12.2 (MIT, vendored) configured with poetry's OPERATOR REGISTER - the component contract in GUI-operator vocabulary: `includeAttributes: ["data-component", "data-slot"]` plus per-page instructions served at [/operator-register.json](/operator-register.json). Nothing loads until a visitor activates it (bring-your-own OpenAI-compatible key, session-only). The task list on the page is the findings pass: each task is pre-classified as ARIA-alone / register-helps / expected-failure-on-the-agent's-input-layer (keyboard-first components cannot be driven by synthetic clicks).
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
        "Demos" => DocsCatalog.demos }.each do |title, entries|
        out << "## #{title}\n\n" + entries.map { |e| "- [#{e.title}](#{e.path}): #{e.description}" }.join("\n")
      end
      out << <<~MD
        ## Machine-readable resources

        - [Component catalog for agents](/poetry/llms.txt) and [full contracts + Stimulus wiring](/poetry/llms-full.txt)
        - [Registry index](/r/registry.json) - shadcn-schema items; install with `bin/rails g poetry:add <name>` or `npx shadcn add`
        - [Agent skills](/.well-known/skills/index.json) - web-installable skill files (also at /.well-known/agent-skills/)
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
