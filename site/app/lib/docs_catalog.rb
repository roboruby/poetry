# The single source for what the site documents: both gem registries -
# the same files the gems' CI drift-gates - drive the sidebar, the command
# palette, and the routable slugs. Nothing here is hand-maintained; a new
# component appears in the nav the moment its gem registers it.
class DocsCatalog
  Entry = Struct.new(:slug, :title, :section, keyword_init: true) do
    def path = "/#{section}/#{slug}"
  end

  # Chart chrome components documented THROUGH the family pages, not as
  # their own entries.
  CHART_CHROME = %w[container legend_content tooltip_content tooltip_layer].freeze

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

    def find(section, slug)
      list = section == "charts" ? charts : components
      list.find { |entry| entry.slug == slug }
    end

    def all = components + charts

    private

    def registry_keys(root)
      YAML.safe_load_file(root.join("config/component_registry.yml")).fetch("components").keys
    end

    def titleize(slug)
      slug.split("-").map(&:capitalize).join(" ")
    end
  end
end
