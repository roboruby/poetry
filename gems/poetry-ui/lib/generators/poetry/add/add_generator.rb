# frozen_string_literal: true

require "rails/generators"
require "yaml"
require_relative "../block/block_generator"

module Poetry
  # `rails g poetry:add Button [@acme/fancy-chart ...]` - the copy-in tier
  # plus the ecosystem address scheme (Ecosystem v1).
  #
  # Bare names and @poetry/* are the installed gems' own items: component
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
  # Every install records provenance in the manifest.
  class AddGenerator < Rails::Generators::Base
    argument :addresses, type: :array,
                         banner: "Component|@registry/item|https://…/item.json|./item.json ..."

    # Composition edges - single-sourced on the gem module since (the
    # registry items emit the same map as registryDependencies).
    DEPENDENCIES = Poetry::Ui::COMPONENT_DEPENDENCIES

    MANIFEST = "config/poetry_components.yml"
    TAILWIND_ENTRY = "app/assets/tailwind/application.css"

    desc "Copy poetry components/blocks (plus dependencies) into the app, from the gems or any registry address"

    def add_components
      local, remote = addresses.map { |raw| Poetry::Core::RegistryAddress.parse(raw) }
                               .partition { |address| local?(address) }
      install_local(local) if local.any?
      install_remote(remote) if remote.any?
    end

    private

    # Bare names and @poetry/* resolve against the installed gems; anything
    # the gems don't ship is a hard error for @poetry (never a fetch - the
    # gem IS the official registry on a poetry host) and a hard error with
    # the classic message for bare names.
    def local?(address)
      address.kind == :bare || (address.kind == :namespace && address.namespace == "@poetry")
    end

    def install_local(local)
      names = local.map { |address| address.name.tr("-", "_") }
      components, rest = names.partition { |name| source_dir(name).directory? }
      blocks, rest = rest.partition { |name| gem_blocks.include?(name.tr("_", "-")) }
      recipes, missing = rest.partition { |name| gem_recipes.include?(name.tr("_", "-")) }
      raise ArgumentError, "unknown component(s): #{missing.join(", ")}" if missing.any?

      copy_components(components) if components.any?
      blocks.each { |name| install_block(name.tr("_", "-")) }
      recipes.each { |name| install_recipe(name.tr("_", "-")) }
    end

    def copy_components(names)
      resolved = resolve(names)
      resolved.each { |name| copy_component(name) }
      record_in_manifest(resolved.to_h { |name| [name, { "version" => Poetry::Ui::VERSION }] })
      # A newly-shadowing file is not hot-reloaded over the already-loaded
      # gem constant (fresh-app proof, 2026-07-01).
      say_status :note, "restart your server so the local copies take precedence over the gem", :yellow
    end

    def resolve(names, seen = [])
      names.each do |name|
        next if seen.include?(name)

        seen << name
        resolve(DEPENDENCIES.fetch(name, []), seen)
      end
      seen
    end

    def source_dir(name)
      Poetry::Ui.root.join("app/components/poetry/ui", name)
    end

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

    # -- the remote path (Ecosystem v1) ------------------------------

    def install_remote(remote)
      plan = build_plan(remote)
      plan.writes.each { |write| create_file write.target, write.content, skip: true }
      plan.block_installs.each { |name| install_block(name) }
      apply_css(plan)
      report(plan)
      record_in_manifest(plan.manifest)
    end

    def build_plan(remote)
      config = manifest_config
      client = Poetry::Core::RegistryClient.new(
        registries: config["registries"] || {}, directory: config["directory"],
        base_dir: destination_root
      )
      Poetry::Core::RegistryInstaller.new(
        client: client, destination_root: destination_root,
        local_components: gem_components, local_blocks: gem_blocks
      ).plan(remote)
    end

    def apply_css(plan)
      plan.css_writes.each { |css| create_file css[:path], css[:content], skip: true }
      return if plan.entry_lines.empty?

      unless File.exist?(File.join(destination_root, TAILWIND_ENTRY))
        say_status :note, "no #{TAILWIND_ENTRY} - add yourself: #{plan.entry_lines.join(" ")}", :yellow
        return
      end
      plan.entry_lines.each { |line| inject_unless_present(TAILWIND_ENTRY, line) }
    end

    def report(plan)
      plan.gem_satisfied.each do |name|
        say_status :runtime, "#{name} - provided by the installed poetry gems (no copy needed)", :cyan
      end
      plan.gem_deps.each do |dep|
        say_status :gemfile, "this item needs gem #{dep.inspect} - add it to your Gemfile (never run for you)", :yellow
      end
      plan.docs.each { |docs| say_status :docs, docs, :blue }
    end

    def install_block(name)
      BlockGenerator.new([name], [], destination_root: destination_root).invoke_all
    end

    # -- recipes (Recipes Channel v1) ---------------------------------------

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

    def gem_blocks
      @gem_blocks ||= begin
        registry = YAML.safe_load_file(Poetry::Ui.root.join(Poetry::Core::Registry::RELATIVE_PATH))
        (registry["blocks"] || {}).keys
      end
    end

    def gem_item_sources
      sources = [[Poetry::Ui.root, "poetry/ui/"]]
      sources << [Poetry::Charts.root, "poetry/charts/"] if defined?(Poetry::Charts::Engine)
      sources
    end

    def manifest_config
      path = File.join(destination_root, MANIFEST)
      config = File.exist?(path) ? YAML.safe_load_file(path) : nil
      config.is_a?(Hash) ? config : {}
    end

    def record_in_manifest(entries, section: "components")
      manifest = manifest_config
      manifest[section] = {} unless manifest[section].is_a?(Hash)
      entries.each { |name, record| manifest[section][name] ||= record }
      create_file MANIFEST, YAML.dump(manifest), force: true
    end

    # The idempotency lives in the file-mutation primitive (the vite_ruby
    # review lesson) - same as poetry:install's.
    def inject_unless_present(relative, line)
      path = File.join(destination_root, relative)
      return if File.exist?(path) && File.read(path).include?(line)

      append_to_file relative, "#{line}\n"
    end
  end
end
