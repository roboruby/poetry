# The single source for what the site documents: both gem registries -
# the same files the gems' CI drift-gates - drive the sidebar, the command
# palette, and the routable slugs. Nothing here is hand-maintained; a new
# component appears in the nav the moment its gem registers it.
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
    Entry.new(slug: "theming", title: "Theming", section: "docs", icon: :palette,
              description: "All nine upstream themes: install-time selection with --theme, the " \
                           "docs style switcher mechanism, and the lyra/sera font-pairing story."),
    Entry.new(slug: "typography", title: "Typography", section: "docs", icon: :type,
              description: "Heading, paragraph, list, table, and inline-text recipes on poetry " \
                           "tokens — class strings transcribed from upstream at the pin. Fonts " \
                           "ride the theme: the same markup goes mono under lyra, serif under sera."),
    Entry.new(slug: "deferred", title: "Deferred Regions", section: "docs", icon: :timer,
              description: "poetry_deferred(src:) — Turbo owns the loading physics (lazy fetches " \
                           "on visibility, so hidden Tabs panels and HoverCards defer for free); " \
                           "poetry owns the states: a Skeleton placeholder and a retryable error card.")
  ].freeze

  # The interaction demos are the one hand-curated section: full-page
  # machinery (server round trips, streaming, cross-chart sync) that no
  # single registry component owns.
  DEMOS = [
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
      @components ||= registry_keys(Poetry::Ui.root).map do |key|
        slug = key.split("/")[2..].join("-").tr("_", "-")
        Entry.new(slug: slug, title: titleize(slug), section: "components")
      end.sort_by(&:slug)
    end

    def charts
      @charts ||= registry_keys(Poetry::Charts.root).filter_map do |key|
        name = key.split("/").last
        next if CHART_CHROME.include?(name)

        slug = name.delete_suffix("_chart").tr("_", "-")
        Entry.new(slug: slug, title: "#{titleize(slug)} Chart", section: "charts")
      end.sort_by(&:slug)
    end

    def demos = DEMOS

    def docs = DOCS

    # The blocks gallery (Blocks v1): registry-driven like components - the
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
      list = { "charts" => charts, "demos" => demos, "blocks" => blocks }.fetch(section, components)
      list.find { |entry| entry.slug == slug }
    end

    def all = docs + components + charts + blocks + demos

    private

    def registry_keys(root)
      YAML.safe_load_file(root.join("config/component_registry.yml")).fetch("components").keys
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
