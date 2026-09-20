# frozen_string_literal: true

module Poetry
  module Ui
    # What the two fidelity contracts (themes, dictionaries) share: the
    # two-way reconciliation of one item's diff kinds against its record.
    module Fidelity
      module_function

      # Adds a finding for every value a diff carries that the record lacks,
      # and for every recorded value the diff no longer carries.
      #
      # @param label [String] the item the findings name
      # @param kinds [Array<String>] the diff kinds to reconcile
      # @param actual [Hash] the item's diff, values by kind
      # @param recorded [Hash] the item's record, values by kind
      # @param findings [Array<String>] the list the findings join
      def reconcile_kinds(label, kinds, actual, recorded, findings)
        kinds.each do |kind|
          missing = (actual[kind] || []) - (recorded[kind] || [])
          stale = (recorded[kind] || []) - (actual[kind] || [])
          findings << "#{label} #{kind} not recorded: #{missing.join(" ")}" if missing.any?
          findings << "#{label} recorded #{kind} now stale: #{stale.join(" ")}" if stale.any?
        end
      end
    end
  end
end
