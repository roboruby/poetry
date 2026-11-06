# frozen_string_literal: true

require_relative "../add/add_generator"

module Poetry
  # `rails g poetry:update [item ...]` - brings the items installed from
  # a registry to the registry's current version without losing an edit.
  # The install record holds a digest of every file as it was written,
  # so the generator knows which files the app changed since:
  #
  # - a file the app has not edited is replaced with the registry's;
  # - a file the app edited is kept, and named, when the registry's
  #   differs; `--force` replaces it too;
  # - a file the item gained is written, and one it dropped is named,
  #   never deleted.
  #
  # The record moves with the files: a replaced file takes the new
  # digest, a kept one keeps the digest it was installed with, and the
  # item's version moves once every file is the registry's. With no
  # name it updates every registry item on record. `poetry:diff` shows
  # the same comparison without writing.
  #
  # @example
  #   bin/rails g poetry:update
  #   bin/rails g poetry:update acme-pricing-table
  class UpdateGenerator < AddGenerator
    remove_argument :addresses
    remove_command :add_components

    argument :names, type: :array, default: [], banner: "[item ...]"

    desc "Bring items installed from a registry to its current version, keeping the files you edited"

    # Generator step: updates the named items, or every registry item on record.
    # @api private
    def update_items
      records = registry_records
      return say("no registry items recorded in #{MANIFEST} - nothing to update") if records.empty?

      @recorded_digests = records.each_value.flat_map { |record| (record["files"] || {}).to_a }.to_h
      chosen(records).each { |name| update_item(name, records.fetch(name)) }
    end

    private

    # The items to update: every one on record, or the names given (an
    # address works too, by its item name).
    def chosen(records)
      return records.keys if names.empty?

      names.map { |raw| raw.split("/").last.delete_suffix(".json") }.each do |name|
        next if records.key?(name)

        raise ArgumentError, "#{name} is not an item installed from a registry " \
                             "(#{MANIFEST} records: #{records.keys.join(", ")})"
      end
    end

    # Updates one item from the registry's copy of it as it stands now, or
    # says there is nothing newer. A registry that does not answer is
    # reported and the item left as it is.
    def update_item(name, record)
      current, plan = current_item(name, record)
      drift = drift_of(record, current)
      unless drift.update?
        return say_status(:current, "#{name} - #{record["version"] || "installed"}: the registry has nothing newer",
                          :green)
      end

      say_status :update, "#{name} - #{record["version"] || "no version on record"} to " \
                          "#{current["version"] || "the registry's item"}", :green
      install_plan(plan)
      drift.files.each do |target, state|
        next unless state == :gone

        say_status :stale, "#{target} - no longer part of #{name}; delete it if nothing of yours uses it", :yellow
      end
    rescue Poetry::Core::RegistryClient::Error => e
      say_status :error, "#{name} - could not ask #{record["source"]}: #{e.message}", :red
    end

    # One file of an item into the app. A file the app has not edited
    # since it was installed is replaced. An edited one is kept: quietly
    # when the registry's is still what was installed, and named when the
    # registry's changed too. --force replaces either.
    def place(target, content)
      mine = digest_at(target)
      fresh = Poetry::Core::RegistryInstaller.digest(content)
      recorded = @recorded_digests[target]
      if mine.nil? || mine == fresh
        create_file target, content, skip: true
      elsif mine == recorded || options[:force]
        create_file target, content, force: true
      elsif fresh != recorded
        say_status :kept, "#{target} - edited here, and changed in the registry (--force replaces it)", :yellow
      end
    end
  end
end
