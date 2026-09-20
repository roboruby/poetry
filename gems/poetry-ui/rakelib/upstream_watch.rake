# frozen_string_literal: true

# The report-only upstream watch (see lib/poetry/ui/upstream_watch.rb).
# Neither task joins the default gate: both need an upstream checkout
# (UPSTREAM_DIR, default ~/Desktop/save/shadcn-ui) and pin/watch is a
# human cadence, not a CI one.
namespace :upstream do
  manifest_path = File.expand_path("../config/upstream_watch.json", __dir__)

  upstream_root = lambda do
    root = ENV.fetch("UPSTREAM_DIR", File.expand_path("~/Desktop/save/shadcn-ui"))
    abort "no upstream checkout at #{root} (set UPSTREAM_DIR)" unless Dir.exist?(root)
    root
  end

  desc "Pin the upstream watch manifest to the current UPSTREAM_DIR checkout"
  task :pin do
    require "yaml"
    require_relative "../lib/poetry/ui/upstream_watch"

    root = upstream_root.call
    sha = `git -C #{root} rev-parse --short HEAD`.strip
    manifest = Poetry::Ui::UpstreamWatch.build_manifest(
      root, pin: sha, generated_at: Time.now.strftime("%Y-%m-%d")
    )
    File.write(manifest_path, JSON.pretty_generate(manifest))
    puts "pinned #{manifest["families"].size} families + " \
         "#{manifest["watched_files"].size} watched files at #{sha} " \
         "-> #{manifest_path}"
  end

  desc "Report upstream drift since the pin (PULL=1 to git pull the checkout first)"
  task :watch do
    require "yaml"
    require_relative "../lib/poetry/ui/upstream_watch"

    root = upstream_root.call
    system("git", "-C", root, "pull", "--ff-only") if ENV["PULL"]
    abort "no manifest at #{manifest_path} - run rake upstream:pin first" unless File.exist?(manifest_path)

    manifest = JSON.parse(File.read(manifest_path))
    current = Poetry::Ui::UpstreamWatch.build_manifest(
      root, pin: nil, generated_at: nil
    )
    diff = Poetry::Ui::UpstreamWatch.diff(manifest, current)

    roster = YAML.load_file(File.expand_path("../config/component_registry.yml", __dir__))
                 .fetch("components").keys.map { |k| k.split("/").last }
    sha = `git -C #{root} rev-parse --short HEAD`.strip
    puts "pin #{manifest["pin"]} (#{manifest["generated_at"]}) vs checkout #{sha}:"
    puts Poetry::Ui::UpstreamWatch.format_report(diff, roster: roster)

    violations = Poetry::Ui::UpstreamWatch.verbatim_violations(diff)
    abort "VERBATIM families changed upstream: #{violations.join(", ")}" if violations.any?
  end
end
