# The single source for what the site documents: both gem registries -
# the same files the gems' CI drift-gates - drive the sidebar, the command
# palette, and the routable slugs. Nothing here is hand-maintained; a new
# component appears in the nav the moment its gem registers it.
#
# @example Every routable docs page
#   DocsCatalog.all.map(&:path)
class DocsCatalog
  Entry = Struct.new(:slug, :title, :section, :description, :icon, keyword_init: true) do
    # Docs guides are top-level routes (/theming, /typography); the gallery
    # sections nest under their section prefix.
    def path = section == "docs" ? "/#{slug}" : "/#{section}/#{slug}"
  end

  # Chart chrome components documented THROUGH the family pages, not as
  # their own entries.
  CHART_CHROME = %w[container legend_content tooltip_content tooltip_layer].freeze

  # Hand-curated guide pages: cross-component content no single registry
  # entry owns. Each has its own controller action; entries here feed the
  # sidebar, the palette, the search index, and the 200-gate.
  DOCS = [
    Entry.new(slug: "installation", title: "Installation", section: "docs", icon: :package,
              description: "Install and upgrade: what poetry:install wires (idempotent, theme-sticky " \
                           "re-runs), the three ownership tiers, and the poetry:diff copy-in report — " \
                           "the install generator is the upgrade path, not a one-shot."),
    Entry.new(slug: "theming", title: "Theming", section: "docs", icon: :palette,
              description: "All nine upstream themes: install-time selection with --theme, the " \
                           "docs style switcher mechanism, and the lyra/sera font-pairing story."),
    Entry.new(slug: "typography", title: "Typography", section: "docs", icon: :type,
              description: "Heading, paragraph, list, table, and inline-text recipes on poetry " \
                           "tokens — class strings transcribed from upstream at the pin. Fonts " \
                           "ride the theme: the same markup goes mono under lyra, serif under sera."),
    Entry.new(slug: "testing", title: "Testing", section: "docs", icon: :"flask-conical",
              description: "Test poetry UIs at the cheapest tier that can catch the bug: wiring " \
                       "asserts on rendered contracts, behavior through the Testing helpers " \
                       "(poetry_dialog, poetry_select, poetry_combobox, poetry_dropdown_menu), " \
                       "and the browser only for what needs a layout engine."),
    Entry.new(slug: "forms", title: "Form Builder", section: "docs", icon: :pencil,
              description: "The model-bound FormBuilder: form_with(builder:) + f.input for one-call " \
                           "fields - label, value, errors, aria, and validation attributes all derived " \
                           "from the object; type inference into poetry's vocabulary, f.association, " \
                           "and the poetry_form -> simple_form i18n chain."),
    Entry.new(slug: "pagination", title: "Pagination", section: "docs", icon: :"chevrons-left-right",
              description: "Pagination through the gem you already use: bin/rails g " \
                           "poetry:pagination installs a host-owned adapter for kaminari, pagy " \
                           "(v43+), or will_paginate - existing paginate / poetry_pagy_nav / " \
                           "will_paginate calls render poetry's nav. This page's examples run " \
                           "live on all three gems."),
    Entry.new(slug: "deferred", title: "Deferred Regions", section: "docs", icon: :timer,
              description: "poetry_deferred(src:) — Turbo owns the loading physics (lazy fetches " \
                           "on visibility, so hidden Tabs panels and HoverCards defer for free); " \
                           "poetry owns the states: a Skeleton placeholder and a retryable error card."),
    Entry.new(slug: "optimistic-forms", title: "Optimistic Forms", section: "docs", icon: :zap,
              description: "poetry_optimistic_form — the predicted result paints on submit as a " \
                           "server-authored Turbo Stream; the server corrects only on rejection " \
                           "(morph refresh). One vocabulary for prediction and truth, plus the " \
                           "204/no-redirect server contract."),
    Entry.new(slug: "recipes", title: "Recipes", section: "docs", icon: :package,
              description: "Multi-file payloads beyond components: skill bundles, the scaffold " \
                           "template set, and screen slices (controller + view + system test, " \
                           "blocks pulled as dependencies) - installable with bin/rails g " \
                           "poetry:add <name> or any shadcn-compatible registry client."),
    Entry.new(slug: "agent", title: "Agent", section: "docs", icon: :bot,
              description: "The operator-register demo: this site embeds page-agent (pinned, " \
                           "opt-in, bring-your-own key) configured with poetry's operator " \
                           "register - watch a GUI agent operate the components, and see which " \
                           "tasks succeed through ARIA alone."),
    Entry.new(slug: "agent-skills", title: "Agent Skills", section: "docs", icon: :"graduation-cap",
              description: "The installable skills catalog: what each skill teaches, served live " \
                           "with a discovery index (agentskills.io schema, sha256 digests) so " \
                           "npx skills, a curl one-liner, or bin/rails g poetry:skill drops the " \
                           "same SKILL.md set into any agent's skills directory."),
    Entry.new(slug: "editors", title: "Editors", section: "docs", icon: :code,
              description: "bin/rails g poetry:editor wires poetry's MCP server and registry-driven " \
                           "snippets into the editors a Rails team uses (VS Code, Cursor, Claude Code, " \
                           "Zed, RubyMine): safe MCP-config upserts, a per-editor matrix, and the " \
                           "Figma / Paper design-tool token bridges."),
    Entry.new(slug: "api", title: "API Reference", section: "docs", icon: :braces,
              description: "The Ruby surface, generated from the gems' source documentation: " \
                           "component options, slots, and style axes on each gallery page, plus " \
                           "per-gem pages for the base classes, DSLs, helpers, and supporting gems."),
    Entry.new(slug: "data-table", title: "Data Table", section: "docs", icon: :"table-2",
              description: "The server-driven table: DataTable::State.from_params with a " \
                       "sortable: whitelist, URL-state sorting, filtering and pagination, " \
                       "row selection, and sticky headers - a full controller-to-view recipe."),
    Entry.new(slug: "caching", title: "Caching", section: "docs", icon: :database,
              description: "Fragment-caching poetry safely: the version-keyed cache recipe, and " \
                       "why unkeyed fragments go silently stale across component upgrades."),
    Entry.new(slug: "stable-ids", title: "Stable IDs", section: "docs", icon: :hash,
              description: "poetry ids are unique per render by default - what that means for " \
                       "fragment caches, Turbo morph and ETags, and the id: token contract " \
                       "that pins them when identity matters."),
    Entry.new(slug: "accessibility", title: "Accessibility", section: "docs", icon: :accessibility,
              description: "What poetry guarantees by construction - required accessible names, " \
                       "Field-chain aria wiring, native form participation, overlay focus - " \
                       "and the keyboard and screen-reader checklist for verifying your app."),
    Entry.new(slug: "mcp", title: "MCP", section: "docs", icon: :plug,
              description: "The boot-free MCP server behind agent workflows: what each of the " \
                       "ten registry-backed tools does and when an agent reaches for it, " \
                       "and how it fits with llms.txt and the installable skills.")
  ].freeze

  # The interaction demos are the one hand-curated section: full-page
  # machinery (server round trips, streaming, cross-chart sync) that no
  # single registry component owns.
  DEMOS = [
    Entry.new(slug: "chat-replay", title: "Chat Replay", section: "demos",
              description: "A scripted AI conversation replayed through the REAL streaming " \
                           "pipeline - Poetry::Ui::Chat's deterministic frames arriving as " \
                           "versioned Turbo Stream morphs into MessageScroller: token-paced " \
                           "text, a tool call flipping loading to done, and a human-in-the-loop " \
                           "approval where the pause is a form and the continuation is the " \
                           "stream after your decision. No model, no key, same bytes every run."),
    Entry.new(slug: "interactive", title: "Interactive Filter", section: "demos",
              description: "Upstream's interactive blocks are useState filters. Here the filter " \
                           "is a real form: submitting re-renders the chart on the server and Turbo " \
                           "swaps it in. Switch the traffic dataset and the chart morphs between " \
                           "renders; switch the period and the entrance replays instead."),
    Entry.new(slug: "live", title: "Live Streaming", section: "demos",
              description: "The server renders the first frame complete; a ticker then streams a " \
                           "sliding window through the payload-script channel and the client kernel " \
                           "redraws — zero further server round trips. Hover while it runs: the " \
                           "tooltip keeps serving fresh values."),
    Entry.new(slug: "sync", title: "Synced Tooltips", section: "demos",
              description: "Two charts share one sync group. Hover or arrow-key either chart and " \
                           "both tooltips follow the same index — recharts' syncId, without a " \
                           "client chart library."),
    Entry.new(slug: "window", title: "Brush & Zoom", section: "demos",
              description: "A year of data behind the window mechanism: drag the brush handles (or " \
                           "the window body) to slice it, drag a range on the plot to zoom in, " \
                           "double-click to reset. Everything recomputes client-side.")
  ].freeze

  class << self
    def components
      @components ||= registry_components(Poetry::Ui.root).map do |key, entry|
        slug = key.split("/")[2..].join("-").tr("_", "-")
        Entry.new(slug: slug, title: titleize(slug), section: "components",
                  description: entry["description"])
      end.sort_by(&:slug)
    end

    def charts
      @charts ||= registry_components(Poetry::Charts.root).filter_map do |key, entry|
        name = key.split("/").last
        next if CHART_CHROME.include?(name)

        slug = name.delete_suffix("_chart").tr("_", "-")
        Entry.new(slug: slug, title: "#{titleize(slug)} Chart", section: "charts",
                  description: entry["description"])
      end.sort_by(&:slug)
    end

    def demos = DEMOS

    def docs = DOCS

    # The sidebar's guide sections. Order within a section is the display
    # order; Agent stays last in AI Native while it is experimental.
    DOC_SECTIONS = {
      "Get Started" => %w[installation theming typography testing editors api],
      "Advanced" => %w[accessibility forms pagination data-table deferred optimistic-forms caching stable-ids],
      "AI Native" => %w[recipes agent-skills mcp agent]
    }.freeze

    # DOC_SECTIONS resolved to entries. Raises when the section map and
    # DOCS drift (a new guide page must be placed in a section, or it
    # silently vanishes from the sidebar).
    def doc_sections
      @doc_sections ||= begin
        by_slug = docs.index_by(&:slug)
        sectioned = DOC_SECTIONS.values.flatten
        missing = sectioned - by_slug.keys
        unplaced = by_slug.keys - sectioned
        raise "doc_sections references unknown slugs: #{missing.join(", ")}" if missing.any?
        raise "guide pages missing from DOC_SECTIONS: #{unplaced.join(", ")}" if unplaced.any?

        DOC_SECTIONS.transform_values { |slugs| slugs.map { |slug| by_slug.fetch(slug) } }
      end
    end

    # The /api reference pages: one per gem with a committed YARD export
    # (data/api/*.json - regenerated by docs:api_reference).
    def apis
      @apis ||= ApiReference.slugs.map do |slug|
        Entry.new(slug: slug, title: ApiReference.meta(slug)["title"], section: "api",
                  icon: :braces, description: ApiReference.meta(slug)["description"])
      end
    end

    # The blocks gallery: registry-driven like components - the
    # blocks section of poetry-ui's registry is the roster, so a new block
    # appears in the nav, palette, and 200-gate the moment the gem ships it.
    def blocks
      @blocks ||= blocks_meta.map do |slug, entry|
        Entry.new(slug: slug, title: entry["title"], section: "blocks",
                  description: entry["description"])
      end.sort_by(&:slug)
    end

    # The raw registry entry (template path, composed components) for one
    # block - the block page reads the real source through it.
    def block_meta(slug) = blocks_meta[slug]

    def find(section, slug)
      list = { "charts" => charts, "demos" => demos, "blocks" => blocks,
               "api" => apis }.fetch(section, components)
      list.find { |entry| entry.slug == slug }
    end

    def all = docs + components + charts + blocks + demos + apis

    # The component class behind a gallery page - keys the YARD-export
    # lookup for the page's API section.
    def class_name_for(section, slug)
      case section
      when "components" then component_class_names[slug]
      when "charts" then chart_class_names[slug]
      end
    end

    # The DOM-verified part contract for a gallery page, or nil -
    # feeds the Styling tables on component and chart pages.
    def parts_for(section, slug)
      case section
      when "components" then component_parts[slug]
      when "charts" then chart_parts[slug]
      end
    end

    # The element-level wiring projection (use_stimulus declarations) -
    # rendered as the Wiring table beside the Styling tables.
    def wiring_for(section, slug)
      case section
      when "components" then component_wiring[slug]
      when "charts" then chart_wiring[slug]
      end
    end

    private

    def component_parts
      @component_parts ||= registry_components(Poetry::Ui.root).to_h do |key, entry|
        [ key.split("/")[2..].join("-").tr("_", "-"), entry["parts"] ]
      end
    end

    def component_class_names
      @component_class_names ||= registry_components(Poetry::Ui.root).to_h do |key, entry|
        [ key.split("/")[2..].join("-").tr("_", "-"), entry["class_name"] ]
      end
    end

    def chart_class_names
      @chart_class_names ||= registry_components(Poetry::Charts.root).to_h do |key, entry|
        [ key.split("/").last.delete_suffix("_chart").tr("_", "-"), entry["class_name"] ]
      end
    end

    def component_wiring
      @component_wiring ||= registry_components(Poetry::Ui.root).to_h do |key, entry|
        [ key.split("/")[2..].join("-").tr("_", "-"), entry["stimulus"] ]
      end
    end

    def chart_wiring
      @chart_wiring ||= registry_components(Poetry::Charts.root).to_h do |key, entry|
        [ key.split("/").last.delete_suffix("_chart").tr("_", "-"), entry["stimulus"] ]
      end
    end

    def chart_parts
      @chart_parts ||= registry_components(Poetry::Charts.root).to_h do |key, entry|
        [ key.split("/").last.delete_suffix("_chart").tr("_", "-"), entry["parts"] ]
      end
    end

    def registry_keys(root)
      registry_components(root).keys
    end

    def registry_components(root)
      YAML.safe_load_file(root.join("config/component_registry.yml")).fetch("components")
    end

    def blocks_meta
      @blocks_meta ||= YAML.safe_load_file(
        Poetry::Ui.root.join("config/component_registry.yml")
      )["blocks"] || {}
    end

    def titleize(slug)
      slug.split("-").map(&:capitalize).join(" ")
    end
  end
end
