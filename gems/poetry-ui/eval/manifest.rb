# frozen_string_literal: true

require "json"

module Poetry
  module Eval
    # A resumable run's manifest (generation-manifest.json and its
    # degradation twin): the units recorded so far by task and arm, the
    # run's config and its usage totals, rewritten whole after every unit
    # so a killed run resumes exactly where it stopped.
    class Manifest
      # The file the manifest lives in.
      attr_reader :path
      # The manifest as a hash, the shape the file holds.
      attr_reader :data

      # Reads the manifest at the path, or starts an empty one.
      def initialize(path)
        @path = path
        @data = path.exist? ? JSON.parse(path.read) : {}
        @data["units"] ||= {}
      end

      # Records the run's config.
      def config=(config)
        data["config"] = config
      end

      # The receipted spend of every earlier run this manifest accumulates.
      def prior_receipted
        data.dig("usage", "receipted_cost_usd") || 0.0
      end

      # A task and arm's recorded entry, or nil.
      def entry(task, arm)
        data["units"].dig(task, arm)
      end

      # Every recorded entry.
      def entries
        data["units"].values.flat_map(&:values)
      end

      # The usage totals recorded so far.
      def usage
        data["usage"] || {}
      end

      # The units still to run: every unit when forced; otherwise those
      # without an entry, with an error entry (a placeholder artifact - a
      # plain re-run must retry it, not skip it), or whose artifact the
      # block reports missing.
      def pending(units, force: false)
        return units if force

        units.reject do |task, arm|
          recorded = entry(task, arm)
          recorded && !recorded.key?("error") && yield(task, arm)
        end
      end

      # Records one unit's entry and the usage totals, and writes the file.
      def record(task, arm, entry, usage)
        data["units"][task] ||= {}
        data["units"][task][arm] = entry
        data["usage"] = usage
        path.dirname.mkpath
        path.write(JSON.pretty_generate(data))
      end
    end
  end
end
