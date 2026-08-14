# frozen_string_literal: true

namespace :css do
  desc "Hold upstream's cn-* hook inventory against the classes poetry emits (both directions)"
  task :verify_hooks do
    require "yaml"
    root = File.expand_path("..", __dir__)
    snapshot = File.readlines(File.join(root, "config/upstream_hooks.txt")).map(&:strip).reject(&:empty?)
    manifest = YAML.safe_load_file(File.join(root, "config/hook_coverage.yml")) || {}

    emitted = Dir[File.join(root, "app/components/**/*.{rb,erb}"),
                  File.join(root, "app/helpers/**/*.rb"),
                  File.join(root, "lib/generators/**/*.erb")]
              .flat_map { |f| File.read(f).scan(/cn-[a-z0-9-]+/) }.to_set

    interpolated = (manifest["interpolated"] || []).to_set
    accounted = interpolated.dup
    (manifest["not_applicable"] || {}).each_value { |list| accounted.merge(list || []) }
    (manifest["parked"] || {}).each_value { |list| accounted.merge(list || []) }
    (manifest["emitted_elsewhere"] || {}).each_value { |list| accounted.merge(list || []) }
    (manifest["divergence_lists"] || {}).each_value { |list| accounted.merge(list || []) }

    forward = snapshot.reject { |h| emitted.include?(h) || accounted.include?(h) }

    theme_rules = Dir[File.join(root, "themes/*.css")]
                  .flat_map { |f| File.read(f).scan(/^\.(cn-[a-z0-9-]+)/).flatten }.uniq
    reverse_allowed = (manifest["reverse_allowed"] || []).to_set
    reverse = theme_rules.reject { |h| emitted.include?(h) || interpolated.include?(h) || reverse_allowed.include?(h) }

    failures = []
    if forward.any?
      failures << "upstream hooks unemitted and unaccounted (fix, park, or record the " \
                  "divergence):\n  #{forward.join("\n  ")}"
    end
    if reverse.any?
      failures << "poetry theme rules no markup wears (dead rules - remove or allow):\n  #{reverse.join("\n  ")}"
    end

    if failures.any?
      abort "css:verify_hooks FAILED\n\n#{failures.join("\n\n")}\n\n" \
            "Manifest: config/hook_coverage.yml · Snapshot: config/upstream_hooks.txt"
    end

    puts "hook coverage: #{snapshot.size} upstream hooks accounted " \
         "(#{(snapshot.to_set & emitted).size} emitted, #{interpolated.size} interpolated, " \
         "#{accounted.size - interpolated.size} recorded), #{theme_rules.size} theme rules all worn"
  end
end
