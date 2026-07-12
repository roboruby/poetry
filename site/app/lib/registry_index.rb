# The official poetry registry surface (Ecosystem v1): /r/*.json is
# served LIVE from the gems' committed registries via their item
# projections - never a second hand-maintained copy, so the hosted registry
# is CI-verified-from-source by construction (the upstream port borrow). One flat
# kebab namespace across the gems, collision-checked at first touch.
class RegistryIndex
  class << self
    def item(name)
      return nil unless names.include?(name)

      sources.each do |source|
        found = source.item(name)
        return found if found
      end
      nil
    end

    def summaries
      @summaries ||= sources.flat_map(&:summaries).sort_by { |item| item["name"] }
    end

    def names
      @names ||= begin
        all = sources.flat_map(&:names)
        duplicates = all.tally.select { |_name, count| count > 1 }.keys
        raise "official registry item name collision: #{duplicates.join(", ")}" if duplicates.any?

        all.sort
      end
    end

    private

    def sources
      @sources ||= [ Poetry::Ui.registry_items, Poetry::Charts.registry_items ]
    end
  end
end
