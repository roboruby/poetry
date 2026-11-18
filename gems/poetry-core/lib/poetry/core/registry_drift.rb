# frozen_string_literal: true

module Poetry
  module Core
    # Where an app's copy of a registry item stands: each file the install
    # record names, and each file the registry's item names now, against
    # the file the app holds. The record carries a digest of every file as
    # it was installed (RegistryInstaller's manifest entry), which is what
    # tells an edit made in the app from a change made in the registry.
    #
    # @example
    #   drift = Poetry::Core::RegistryDrift.new(recorded: record["files"], current: entry["files"]) do |target|
    #     digest_of(target)
    #   end
    #   drift.files   # => { "app/components/acme/chart/component.rb" => :upstream }
    #   drift.update? # => true
    class RegistryDrift
      # What each state says of a file, for a report.
      STATES = {
        same: "as installed",
        edited: "edited here",
        missing: "missing here",
        upstream: "changed in the registry",
        both: "changed in the registry, and edited here",
        added: "new in the registry",
        gone: "no longer part of the item"
      }.freeze
      # The states an update has something to do about.
      UPDATES = %i[upstream both added missing].freeze

      # The state of each file the record or the registry's item names.
      # @return [Hash{String => Symbol}] a key of STATES, by target
      attr_reader :files

      # Compares the app's files with the record and, when given, with the
      # registry's item now.
      #
      # @param recorded [Hash{String => String}, nil] the digest of each file
      #   as installed, by target, from the install record
      # @param current [Hash{String => String}, nil] the digest of each file
      #   of the registry's item now; nil when the registry was not asked
      # @yieldparam target [String]
      # @yieldreturn [String, nil] the digest of the app's file, nil for none
      def initialize(recorded:, current: nil, &digest_at)
        recorded = {} unless recorded.is_a?(Hash)
        @asked = !current.nil?
        targets = (recorded.keys + (current || {}).keys).uniq
        @files = targets.to_h do |target|
          [target, state(recorded[target], current && current[target], yield(target))]
        end
      end

      # Whether the registry was asked for the item as it stands now.
      # @return [Boolean]
      def asked? = @asked

      # Whether the registry's item has something this copy lacks.
      # @return [Boolean]
      def update?
        asked? && files.each_value.any? { |state| UPDATES.include?(state) }
      end

      # Whether the app changed a file since it was installed.
      # @return [Boolean]
      def edited?
        files.values.intersect?(%i[edited both])
      end

      # The files that are not as installed, with their states.
      # @return [Hash{String => Symbol}]
      def changes = files.reject { |_, state| state == :same }

      private

      # A file against the record alone when the registry was not asked;
      # otherwise against the registry's item too. A file the app holds in
      # the registry's current form is the same, whatever the record says.
      def state(recorded, upstream, app)
        return local_state(recorded, app) unless asked?
        return :gone if upstream.nil?
        return recorded ? :missing : :added if app.nil?
        return :same if app == upstream
        return :upstream if recorded && app == recorded
        return :edited if recorded && upstream == recorded

        :both
      end

      # A file against the record alone: as installed, edited or missing.
      def local_state(recorded, app)
        return :missing if app.nil?

        app == recorded ? :same : :edited
      end
    end
  end
end
