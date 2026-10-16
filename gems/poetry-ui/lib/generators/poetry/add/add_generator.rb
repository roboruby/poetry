# frozen_string_literal: true

require "rails/generators"
require "yaml"
require_relative "../block/block_generator"

module Poetry
  # `rails g poetry:add Button [@acme/fancy-chart ...]` - the copy-in tier
  # plus the ecosystem address scheme.
  #
  # Bare names and the @poetry/* names the gems ship are the installed
  # gems' own items: component
  # source copies into app/components where Rails autoload precedence
  # shadows the gem ("own the code"; dependencies resolve recursively,
  # existing files are SKIPPED - local edits win, always), and block names
  # hand off to poetry:block. Everything else is a REMOTE registry address -
  # a URL, a local item file, or @namespace/item against the registries:
  # section of config/poetry_components.yml - resolved through
  # RegistryClient + RegistryInstaller: the dependency DAG fetches
  # recursively and writes in topo order, poetry components satisfy at
  # RUNTIME (the gem provides them - no copy), targets are
  # traversal-checked, and gem dependencies are REPORTED, never installed.
  # Every install records provenance in the manifest. An @poetry name the
  # gems do not ship is a community item, fetched from poetryui.com (or the
  # manifest's community: template); a port also lands its origin's
  # license in the host's THIRD_PARTY_NOTICES.md.
  #
  # @example
  #   bin/rails g poetry:add button
  class AddGenerator < Rails::Generators::Base
    argument :addresses, type: :array,
                         banner: "Component|@registry/item|https://…/item.json|./item.json ..."

    # Composition edges - single-sourced on the gem module (the
    # registry items emit the same map as registryDependencies).
    DEPENDENCIES = Poetry::Ui::COMPONENT_DEPENDENCIES

    # The copy-in provenance manifest poetry:install seeds.
    MANIFEST = "config/poetry_components.yml"
    # The host's Tailwind entry stylesheet (for @source injection).
    TAILWIND_ENTRY = "app/assets/tailwind/application.css"
    # Where an item's Stimulus controllers land; a write here refreshes the
    # app's controllers manifest.
    CONTROLLERS_DIR = "app/javascript/controllers/"
    # Where an item's other JavaScript lands (an island's module, a
    # kernel); a write here pins the directory in the host's importmap once.
    COMMUNITY_MODULES_DIR = "app/javascript/community/"
    # The pin that serves app/javascript/community as community/*.
    COMMUNITY_PIN = %(pin_all_from "app/javascript/community", under: "community")
    # Where @poetry names the gems do not ship come from.
    COMMUNITY = "https://poetryui.com/r/{name}.json"
    # The host's credits for the ports it installed.
    NOTICES = "THIRD_PARTY_NOTICES.md"

    desc "Copy poetry components/blocks (plus dependencies) into the app, from the gems or any registry address"

    # Generator step: partitions the addresses and installs local
    # (gem-owned) and remote items.
    # @api private
    def add_components
      local, remote = addresses.map { |raw| Poetry::Core::RegistryAddress.parse(raw) }
                               .partition { |address| local?(address) }
      install_local(local) if local.any?
      install_remote(remote) if remote.any?
    end

    private

    # Bare names resolve against the installed gems, an unknown one a hard
    # error. Names under @poetry do too when the gems ship them; any other
    # name under @poetry is a community item and fetches.
    def local?(address)
      return true if address.kind == :bare
      return false unless address.kind == :namespace && address.namespace == "@poetry"

      name = address.name
      gem_components.include?(name) || gem_blocks.include?(name) || gem_recipes.include?(name)
    end

    # Installs local names: components, blocks and recipes; raises for unknown ones.
    def install_local(local)
      names = local.map { |address| address.name.tr("-", "_") }
      components, rest = names.partition { |name| source_dir(name).directory? }
      blocks, rest = rest.partition { |name| gem_blocks.include?(name.tr("_", "-")) }
      recipes, missing = rest.partition { |name| gem_recipes.include?(name.tr("_", "-")) }
      if missing.any?
        raise ArgumentError, "unknown component(s): #{missing.join(", ")} - for a community item, " \
                             "add it as @poetry/#{missing.first.tr("_", "-")}"
      end

      copy_components(components) if components.any?
      blocks.each { |name| install_block(name.tr("_", "-")) }
      recipes.each { |name| install_recipe(name.tr("_", "-")) }
    end

    # Copies the components with their dependencies and records them in the manifest.
    def copy_components(names)
      resolved = resolve(names)
      resolved.each { |name| copy_component(name) }
      record_in_manifest(resolved.to_h { |name| [name, { "version" => Poetry::Ui::VERSION }] })
      # A newly-shadowing file is not hot-reloaded over the already-loaded
      # gem constant.
      say_status :note, "restart your server so the local copies take precedence over the gem", :yellow
    end

    # The names with their dependencies, in install order.
    def resolve(names, seen = [])
      names.each do |name|
        next if seen.include?(name)

        seen << name
        resolve(DEPENDENCIES.fetch(name, []), seen)
      end
      seen
    end

    # A component's directory in the gem.
    def source_dir(name)
      Poetry::Ui.root.join("app/components/poetry/ui", name)
    end

    # Copies a component's files into the app, never overwriting.
    def copy_component(name)
      dir = source_dir(name)
      # Recursive: a component owns its nested subcomponents (command ships
      # command/dialog). skip-if-exists: a customized local copy is never
      # overwritten.
      dir.glob("**/*").select(&:file?).each do |file|
        create_file "app/components/poetry/ui/#{name}/#{file.relative_path_from(dir)}",
                    file.read, skip: true
      end
    end

    # -- the remote path ----------------------------------------------------

    def install_remote(remote)
      plan = build_plan(remote)
      plan.writes.each { |write| create_file write.target, write.content, skip: true }
      plan.block_installs.each { |name| install_block(name) }
      apply_css(plan)
      refresh_controllers_manifest(plan)
      pin_community_modules(plan)
      report(plan)
      credit_origins(plan)
      record_in_manifest(plan.manifest)
    end

    # Each port's origins, licenses and copyrights in the host's notices,
    # with the license texts, once per item: the notice MIT asks to travel
    # with the copy, kept even after the host edits the files. A bundle
    # credits every library inside it.
    def credit_origins(plan)
      plan.provenance.select { |record| record.origins.any? }.each do |record|
        marker = "<!-- poetry:add #{record.name} -->"
        path = File.join(destination_root, NOTICES)
        next if File.exist?(path) && File.read(path).include?(marker)

        create_file NOTICES, "# Third-party notices\n", skip: true unless File.exist?(path)
        entry = ["", marker, "## #{record.name}", ""]
        record.origins.each do |origin|
          entry += ["Adapted from #{origin["registry"]}/#{origin["item"]} (#{origin["url"]}), " \
                    "#{origin["repository"]}.",
                    "License: #{origin["license"]}. #{origin["copyright"]}", ""]
          entry += ["```", origin["notice"].strip, "```", ""] if origin["notice"]
        end
        append_to_file NOTICES, entry.join("\n")
      end
    end

    # An item that brings a Stimulus controller joins the app's controllers
    # manifest straight away (as `bin/rails poetry:stimulus:manifest` would),
    # so the component that names it by Symbol loads, and check validates
    # its wiring. The manifest is read at boot: a running server restarts.
    def refresh_controllers_manifest(plan)
      return if options[:pretend] || behavior == :revoke
      return unless plan.writes.any? { |write| write.target.to_s.start_with?(CONTROLLERS_DIR) }

      result = Poetry::Core::Stimulus::HostManifest.generate!(root: Pathname(destination_root))
      count = result.definitions.size
      say_status :stimulus, "wrote config/controllers_manifest.json (#{count} controller#{"s" unless count == 1}) - " \
                            "commit it, and restart a running server so components that name them load", :green
      result.skipped.each do |skip|
        say_status :stimulus,
                   "skipped #{skip.identifier}: #{skip.reason} (unvalidated until written by hand)", :yellow
      end
    end

    # An item that brings a JavaScript module outside the controllers (an
    # island's bundle, a kernel) lands under app/javascript/community/, and
    # the host's importmap pins that directory once, as community/*, so the
    # module loads by the specifier the item's component names.
    def pin_community_modules(plan)
      return if options[:pretend] || behavior == :revoke
      return unless plan.writes.any? { |write| write.target.to_s.start_with?(COMMUNITY_MODULES_DIR) }

      importmap = "config/importmap.rb"
      unless File.exist?(File.join(destination_root, importmap))
        say_status :note, "no #{importmap} - serve app/javascript/community from your bundler as community/*",
                   :yellow
        return
      end
      return if File.read(File.join(destination_root, importmap)).include?(COMMUNITY_PIN)

      append_to_file importmap, "#{COMMUNITY_PIN}\n"
      say_status :importmap, "pinned app/javascript/community as community/* - the item's module loads by that name",
                 :green
    end

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

    # Writes the plan's stylesheets and adds their import lines to the Tailwind entry.
    def apply_css(plan)
      plan.css_writes.each { |css| create_file css[:path], css[:content], skip: true }
      return if plan.entry_lines.empty?

      unless File.exist?(File.join(destination_root, TAILWIND_ENTRY))
        say_status :note, "no #{TAILWIND_ENTRY} - add yourself: #{plan.entry_lines.join(" ")}", :yellow
        return
      end
      plan.entry_lines.each { |line| inject_unless_present(TAILWIND_ENTRY, line) }
    end

    # Prints what the gems satisfy, the gems to add, and the docs.
    def report(plan)
      plan.gem_satisfied.each do |name|
        say_status :runtime, "#{name} - provided by the installed poetry gems (no copy needed)", :cyan
      end
      plan.gem_deps.each do |dep|
        say_status :gemfile, "this item needs gem #{dep.inspect} - add it to your Gemfile (never run for you)", :yellow
      end
      plan.docs.each { |docs| say_status :docs, docs, :blue }
      plan.provenance.select(&:community).each do |record|
        credits = record.origins.map { |origin| "#{origin["registry"]}/#{origin["item"]} (#{origin["license"]})" }
        origin = credits.any? ? " - adapted from #{credits.join(", ")}" : ""
        say_status :community, "#{record.name}: a community item, reviewed and checked in CI, not audited#{origin}",
                   :cyan
      end
    end

    # Runs the block generator for a name.
    def install_block(name)
      BlockGenerator.new([name], [], destination_root: destination_root).invoke_all
    end

    # -- recipes ------------------------------------------------------------

    # A recipe's files write to their declared targets (skip-if-exists:
    # local edits win, always); its registryDependencies are block names,
    # installed through the same block path. Recorded in the manifest
    # under recipes:.
    def install_recipe(name)
      item = Poetry::Ui.recipe_items.item(name)
      item["files"].each { |file| create_file file["target"], file["content"], skip: true }
      item["registryDependencies"].each { |dep| install_block(dep) }
      record_in_manifest({ name => { "version" => Poetry::Ui::VERSION } }, section: "recipes")
      routes_hint = item["description"][/Add `[^`]+` to routes/]
      say_status :note, routes_hint, :yellow if routes_hint
    end

    # The recipe names the gem ships.
    def gem_recipes
      @gem_recipes ||= Poetry::Ui.recipe_items.names
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

    # Records entries in a manifest section, keeping existing ones.
    def record_in_manifest(entries, section: "components")
      manifest = manifest_config
      manifest[section] = {} unless manifest[section].is_a?(Hash)
      entries.each { |name, record| manifest[section][name] ||= record }
      create_file MANIFEST, YAML.dump(manifest), force: true
    end

    # The idempotency lives in the file-mutation primitive - same as
    # poetry:install's.
    def inject_unless_present(relative, line)
      path = File.join(destination_root, relative)
      return if File.exist?(path) && File.read(path).include?(line)

      append_to_file relative, "#{line}\n"
    end
  end
end
