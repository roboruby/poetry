# frozen_string_literal: true

require "rails/generators"
require "yaml"
require_relative "../registry_planning"

module Poetry
  # `rails g poetry:diff` - the copy-in upgrade report. poetry's
  # three ownership tiers upgrade differently: gem-owned code rides
  # `bundle update`, the vendored css set rides a `poetry:install` re-run,
  # and copy-ins are app-OWNED - nothing may rewrite them. This generator
  # closes the loop on that third tier: it reads the provenance
  # manifest (config/poetry_components.yml) and reports, file by file, where
  # the app's copies stand against what the installed gems ship NOW.
  # Read-only by contract - it prints, it never writes; `poetry:add`
  # re-run is the (skip-if-exists) way to pick up newly-shipped files.
  #
  # An item installed from a registry is reported against its install
  # record (the digest of each file as it was written) and against the
  # registry's item now, so the report tells an edit made here from a
  # change made there; `poetry:update` takes the second. `--offline`
  # leaves the registry unasked and reports the edits alone.
  #
  # @example
  #   bin/rails g poetry:diff
  class DiffGenerator < Rails::Generators::Base
    include RegistryPlanning

    class_option :offline, type: :boolean, default: false,
                           desc: "Do not ask a registry for an item's current version; report local edits only"

    # Where component copy-ins land in the host app.
    COMPONENT_ROOT = "app/components/poetry/ui"
    # Where block copy-ins land in the host app.
    BLOCKS_ROOT = "app/views/blocks"
    # The ownership header poetry:block stamps on copy (stripped before
    # comparing, like the gem template's own poetry:block header).
    BLOCK_HEADER = /\A<%#[^%]*%>\n?/

    desc "Report drift between copied-in poetry components/blocks and what the installed gems ship (read-only)"

    # Step: reports drift for every manifest-recorded component copy-in.
    # @api private
    def report_components
      entries = manifest_config["components"].is_a?(Hash) ? manifest_config["components"] : {}
      if entries.empty?
        say "no copy-ins recorded in #{MANIFEST} - nothing to diff"
      else
        entries.each { |name, record| report_component(name, record) }
      end
    end

    # Step: reports how copied blocks differ from the gem templates.
    # @api private
    def report_blocks
      # A block a registry item wrote is that item's file, reported above.
      installed = registry_records.each_value.flat_map { |record| (record["files"] || {}).keys }
      copied = Dir[File.join(destination_root, BLOCKS_ROOT, "_*.html.erb")]
               .reject { |path| installed.include?(path.delete_prefix("#{destination_root}/")) }
      return if copied.empty?

      say "blocks are app-owned starting points - differing from the gem is normal, not drift:"
      copied.each { |path| report_block(path) }
    end

    private

    # Reports one copied component against the gem: remote, gone, unchanged or changed.
    def report_component(name, record)
      return report_remote(name, record) if record.is_a?(Hash) && record.key?("source")

      version = record.is_a?(Hash) ? record["version"] : nil
      gem_dir = Poetry::Ui.root.join("app/components/poetry/ui", name)
      unless gem_dir.directory?
        say_status :gone, "#{name} - copied at #{version}, no longer shipped by poetry-ui", :yellow
        return
      end

      changes = component_changes(name, gem_dir)
      header = "#{name} - copied at #{version || "unknown"}, gem ships #{Poetry::Ui::VERSION}"
      if changes.empty?
        say_status :same, "#{header}: all files match", :green
      else
        say_status :drift, header, :yellow
        changes.each { |line| say "    #{line}" }
      end
    end

    # One line per file that is not byte-identical, in gem order, then any
    # app-local extras. Line counts, not hunks - the report is a pointer,
    # the diff tool of record is git in the app repo.
    def component_changes(name, gem_dir)
      changes = []
      gem_files = gem_dir.glob("**/*").select(&:file?).sort
      gem_files.each do |file|
        relative = file.relative_path_from(gem_dir)
        app_path = File.join(destination_root, COMPONENT_ROOT, name, relative.to_s)
        if !File.exist?(app_path)
          changes << "#{relative}: not copied locally (new upstream file? `bin/rails g poetry:add #{name}` " \
                     "adds missing files without touching existing ones)"
        elsif File.read(app_path) != file.read
          changes << "#{relative}: differs (app #{File.foreach(app_path).count} lines, " \
                     "gem #{file.each_line.count} lines)"
        end
      end
      app_dir = File.join(destination_root, COMPONENT_ROOT, name)
      Dir[File.join(app_dir, "**/*")].select { |f| File.file?(f) }.sort.each do |path|
        relative = path.delete_prefix("#{app_dir}/")
        changes << "#{relative}: local-only (yours)" unless gem_dir.join(relative).file?
      end
      changes
    end

    # Reports an item installed from a registry: against its record, and
    # against the registry's item now unless told not to ask.
    def report_remote(name, record)
      header = "#{name} - installed from #{record["source"]}#{" at #{record["version"]}" if record["version"]}"
      unless record["files"].is_a?(Hash)
        say_status :remote, "#{header}, with no file digests on record (installed before they were kept); " \
                            "`bin/rails g poetry:add #{record["source"]}` records them", :cyan
        return
      end

      current = options[:offline] ? nil : asked(name, record)
      drift = drift_of(record, current)
      report_drift(name, header, drift, current)
      drift.changes.each { |target, state| say "    #{target}: #{Poetry::Core::RegistryDrift::STATES.fetch(state)}" }
    end

    # The registry's item now, or nil with a line saying why not.
    def asked(name, record)
      current_item(name, record).first
    rescue Poetry::Core::RegistryClient::Error, ArgumentError => e
      say_status :remote, "#{name} - could not ask #{record["source"]}: #{e.message}", :yellow
      nil
    end

    # The one line that says where the item stands.
    def report_drift(name, header, drift, current)
      if drift.update?
        say_status :update, "#{header}; the registry has #{current["version"] || "another form of it"}: " \
                            "`bin/rails g poetry:update #{name}` takes what you have not edited", :yellow
      elsif drift.changes.any?
        say_status :edited,
                   "#{header}: #{drift.asked? ? "the registry has nothing newer" : "the registry was not asked"}", :cyan
      else
        registry = drift.asked? ? ", and the registry has nothing newer" : " (the registry was not asked)"
        say_status :same, "#{header}: every file as installed#{registry}", :green
      end
    end

    # Reports one copied block against the catalog.
    def report_block(path)
      name = File.basename(path, ".html.erb").delete_prefix("_").tr("_", "-")
      entry = block_catalog[name]
      unless entry
        say_status :yours, "#{name} - not in the gem catalog (renamed or your own)", :cyan
        return
      end

      gem_body = Poetry::Ui.root.join(entry.fetch("template")).read.sub(BLOCK_HEADER, "")
      app_body = File.read(path).sub(BLOCK_HEADER, "")
      if app_body == gem_body
        say_status :same, "#{name} - matches the gem's current template", :green
      else
        say_status :edited, "#{name} - differs from the gem's current template " \
                            "(reference: #{entry.fetch("template")})", :cyan
      end
    end

    # The block catalog from the committed registry.
    def block_catalog
      @block_catalog ||= YAML.safe_load_file(
        Poetry::Ui.root.join(Poetry::Core::Registry::RELATIVE_PATH)
      )["blocks"] || {}
    end
  end
end
