# frozen_string_literal: true

require "rails/generators"
require "yaml"
require_relative "../block/block_generator"
require_relative "../registry_planning"

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
  # Every install records provenance in the manifest; an item from a
  # registry also records the version it states and a digest of each file
  # it wrote, what the app's copy started from. An @poetry name the
  # gems do not ship is a community item, fetched from poetryui.com (or the
  # manifest's community: template); a port also lands its origin's
  # license in the host's THIRD_PARTY_NOTICES.md.
  #
  # @example
  #   bin/rails g poetry:add button
  class AddGenerator < Rails::Generators::Base
    include RegistryPlanning

    argument :addresses, type: :array,
                         banner: "Component|@registry/item|https://…/item.json|./item.json ..."

    # Composition edges - single-sourced on the gem module (the
    # registry items emit the same map as registryDependencies).
    DEPENDENCIES = Poetry::Ui::COMPONENT_DEPENDENCIES

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
      install_plan(build_plan(remote))
    end

    # Everything a plan asks for: the files, the blocks, the stylesheets,
    # the controllers manifest, the pins, the report, the credits and the
    # record.
    def install_plan(plan)
      plan.writes.each { |write| place(write.target, write.content) }
      plan.block_installs.each { |name| install_block(name) }
      apply_css(plan)
      refresh_controllers_manifest(plan)
      pin_community_modules(plan)
      report(plan)
      credit_origins(plan)
      record_in_manifest(plan.manifest) { |entry, recorded| installed(entry, recorded) }
    end

    # An item's record as the app now holds it. The plan's entry names the
    # version the item states and the digest of every file it ships; the
    # record takes a file's digest when the app's copy matches the item's
    # (written just now, or the same already), and the version once every
    # file does. A file the app keeps in another form (an edit this run
    # skipped) keeps the digest on record, so each digest names what that
    # file was copied from, and a reinstall (the file deleted and added
    # again, or --force) moves the record to the item as it stands now.
    # A name another source installed keeps its record.
    def installed(entry, recorded)
      return recorded unless recorded.nil? || (recorded.is_a?(Hash) && recorded["source"] == entry["source"])

      shipped = entry.fetch("files", {})
      matched = shipped.select { |target, digest| digest_at(target) == digest }
      return entry if matched.size == shipped.size

      kept = recorded || entry.except("version", "files")
      files = (kept["files"] || {}).merge(matched)
      files.any? ? kept.merge("files" => files) : kept
    end

    # One file of an item into the app: written where there is none, and
    # left alone where there is one. poetry:update decides otherwise.
    def place(target, content)
      create_file target, content, skip: true
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

    # Writes the plan's stylesheets and adds their import lines to the Tailwind entry.
    def apply_css(plan)
      plan.css_writes.each { |css| place(css[:path], css[:content]) }
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

    # Records entries in a manifest section, keeping existing ones; a block
    # decides the record instead, from the entry and the one on record.
    def record_in_manifest(entries, section: "components")
      manifest = manifest_config
      manifest[section] = {} unless manifest[section].is_a?(Hash)
      entries.each do |name, record|
        recorded = manifest[section][name]
        manifest[section][name] = block_given? ? yield(record, recorded) : (recorded || record)
      end
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
