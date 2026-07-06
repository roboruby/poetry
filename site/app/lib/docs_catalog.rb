# The single source for what the site documents: both gem registries -
# the same files the gems' CI drift-gates - drive the sidebar, the command
# palette, and the routable slugs. Nothing here is hand-maintained; a new
# component appears in the nav the moment its gem registers it.
class DocsCatalog
  Entry = Struct.new(:slug, :title, :section, :description, keyword_init: true) do
    def path = "/#{section}/#{slug}"
  end

  # Chart chrome components documented THROUGH the family pages, not as
  # their own entries.
  CHART_CHROME = %w[container legend_content tooltip_content tooltip_layer].freeze

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

    def find(section, slug)
      list = { "charts" => charts, "demos" => demos }.fetch(section, components)
      list.find { |entry| entry.slug == slug }
    end

    def all = components + charts + demos

    private

    def registry_keys(root)
      YAML.safe_load_file(root.join("config/component_registry.yml")).fetch("components").keys
    end

    def titleize(slug)
      slug.split("-").map(&:capitalize).join(" ")
    end
  end
end
