# frozen_string_literal: true

require "yaml"

module Poetry
  # What the generators that reach a registry share: the app's manifest,
  # the names the installed gems provide, the install plan for an
  # address, and the digest of a file the app holds. poetry:add installs
  # from a plan, poetry:diff reads one, poetry:update installs from one
  # with another rule for a file that exists.
  module RegistryPlanning
    # The copy-in provenance manifest poetry:install seeds.
    MANIFEST = "config/poetry_components.yml"
    # Where @poetry names the gems do not ship come from.
    COMMUNITY = "https://poetryui.com/r/{name}.json"

    private

    # The install plan for remote addresses through the registry client.
    def build_plan(remote)
      config = manifest_config
      client = Poetry::Core::RegistryClient.new(
        registries: config["registries"] || {}, directory: config["directory"],
        community: config["community"] || COMMUNITY,
        base_dir: destination_root
      )
      Poetry::Core::RegistryInstaller.new(
        client: client, destination_root: destination_root,
        local_components: gem_components, local_blocks: gem_blocks
      ).plan(remote)
    end

    # The gems' own item names (kebab), read boot-free from the committed
    # registries - what "provided at runtime" means on this host.
    def gem_components
      @gem_components ||= gem_item_sources.flat_map do |root, prefix|
        registry = YAML.safe_load_file(root.join(Poetry::Core::Registry::RELATIVE_PATH))
        (registry["components"] || {}).keys.map { |path| path.delete_prefix(prefix).tr("/", "_").tr("_", "-") }
      end
    end

    # The block names the gem ships.
    def gem_blocks
      @gem_blocks ||= begin
        registry = YAML.safe_load_file(Poetry::Ui.root.join(Poetry::Core::Registry::RELATIVE_PATH))
        (registry["blocks"] || {}).keys
      end
    end

    # The gem roots and path prefixes that provide items.
    def gem_item_sources
      sources = [[Poetry::Ui.root, "poetry/ui/"]]
      sources << [Poetry::Charts.root, "poetry/charts/"] if defined?(Poetry::Charts::Engine)
      sources
    end

    # The manifest as a hash, empty when absent. The overrides ledger
    # writes `created:` as a bare YAML date, so the load permits Date
    # (the design task does the same).
    def manifest_config
      path = File.join(destination_root, MANIFEST)
      config = File.exist?(path) ? YAML.safe_load_file(path, permitted_classes: [Date]) : nil
      config.is_a?(Hash) ? config : {}
    end

    # The items installed from a registry, by name: the manifest's
    # components that record the address they came from.
    def registry_records
      components = manifest_config["components"]
      if components.is_a?(Hash)
        components.select do |_, record|
          record.is_a?(Hash) && record["source"].is_a?(String)
        end
      else
        {}
      end
    end

    # The registry's item as it stands now, in the shape of an install
    # record (its version, the digest of each file), with the plan that
    # would install it.
    # @return [Array(Hash, Poetry::Core::RegistryInstaller::Plan)]
    def current_item(name, record)
      plan = build_plan([Poetry::Core::RegistryAddress.parse(record.fetch("source"))])
      [plan.manifest.fetch(name) do
        raise Poetry::Core::RegistryClient::Error, "#{record["source"]} no longer names #{name}"
      end, plan]
    end

    # Where the app's copy stands against its record and, when given,
    # the registry's item now.
    def drift_of(record, current = nil)
      Poetry::Core::RegistryDrift.new(recorded: record["files"],
                                      current: current && (current["files"] || {})) do |target|
        digest_at(target)
      end
    end

    # The digest of the app's file at a target, nil when there is none.
    def digest_at(target)
      path = File.join(destination_root, target)
      Poetry::Core::RegistryInstaller.digest(File.binread(path)) if File.file?(path)
    end
  end
end
