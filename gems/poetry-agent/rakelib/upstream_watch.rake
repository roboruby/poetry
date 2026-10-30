# frozen_string_literal: true

# The report-only upstream watch (see lib/poetry/agent/upstream_watch.rb).
# Neither task joins the default gate: both need the upstream checkouts
# (UPSTREAM_DIR, default ~/Desktop/save/upstream, holding ag-ui, A2UI and
# ext-apps), and pin/watch is a human cadence, not a CI one. The offline
# verify tasks (agui, a2ui, mcp_apps) stay in the gate.
namespace :upstream do
  manifest_path = File.expand_path("../config/upstream_watch.json", __dir__)
  gem_root = File.expand_path("..", __dir__)

  checkout = lambda do |name|
    dir = File.join(ENV.fetch("UPSTREAM_DIR", File.expand_path("~/Desktop/save/upstream")), name)
    abort "no #{name} checkout at #{dir} (set UPSTREAM_DIR; clone the upstreams under it)" unless File.directory?(dir)
    dir
  end
  head = ->(dir) { `git -C #{dir} rev-parse --short=9 HEAD`.strip }
  mcp_version = -> { Gem::Specification.find_by_name("mcp").version.to_s }

  desc "Pin the upstream watch manifest to the current ag-ui checkout and the installed mcp gem"
  task :pin do
    require_relative "../lib/poetry/agent/upstream_watch"

    root = checkout.call("ag-ui")
    manifest = Poetry::Agent::UpstreamWatch.build_manifest(root, pin: head.call(root),
                                                                 generated_at: Time.now.strftime("%Y-%m-%d"),
                                                                 mcp_version: mcp_version.call)
    File.write(manifest_path, "#{JSON.pretty_generate(manifest)}\n")
    ag_ui = manifest["ag-ui"]
    puts "upstream:pin: ag-ui at #{ag_ui["pin"]} (@ag-ui/core #{ag_ui["core_version"]}), " \
         "#{ag_ui["files"].size} files, #{ag_ui["directories"].size} directories, " \
         "mcp #{manifest["mcp"]["version"]} -> #{manifest_path}"
  end

  desc "Report upstream drift since the pins (PULL=1 pulls the checkouts first, NETWORK=1 asks the registries)"
  task :watch do
    require_relative "../lib/poetry/agent/upstream_watch"
    watch = Poetry::Agent::UpstreamWatch

    abort "no manifest at #{manifest_path} - run rake upstream:pin first" unless File.exist?(manifest_path)
    manifest = JSON.parse(File.read(manifest_path))
    roots = watch::CHECKOUTS.transform_values { |dir| checkout.call(dir) }
    roots.each_value { |dir| system("git", "-C", dir, "pull", "--ff-only", "--quiet") } if ENV["PULL"]
    reports = []
    drifted = false

    pinned = manifest["ag-ui"]
    current = watch.build_ag_ui(roots["ag-ui"])
    diff = watch.diff_ag_ui(pinned, current)
    drifted ||= watch.drift?(diff)
    heading = "pin #{pinned["pin"]} (#{manifest["generated_at"]}) vs checkout #{head.call(roots["ag-ui"])}"
    reports << watch.format_report("ag-ui", heading, diff)

    watch::VENDORED.each do |name, config|
      commit = File.read(File.join(gem_root, config[:commit])).strip
      diff = watch.diff_vendored(File.join(gem_root, config[:sums]), roots[name])
      drifted ||= watch.drift?(diff)
      reports << watch.format_report(name, "vendored at #{commit} vs checkout #{head.call(roots[name])}", diff)
    end

    installed = mcp_version.call
    gem_diff = { "installed" => ([manifest["mcp"]["version"], installed] if installed != manifest["mcp"]["version"]) }
    if ENV["NETWORK"]
      require "net/http"
      latest = JSON.parse(Net::HTTP.get(URI("https://rubygems.org/api/v1/gems/mcp.json")))["version"]
      gem_diff["latest"] = [installed, latest] if latest != installed
      core = JSON.parse(Net::HTTP.get(URI("https://registry.npmjs.org/@ag-ui/core/latest")))["version"]
      gem_diff["core_latest"] = [current["core_version"], core] if core != current["core_version"]
    end
    drifted ||= watch.drift?(gem_diff)
    asked = ENV["NETWORK"] ? ", registries asked" : ""
    reports << watch.format_report("mcp", "pinned #{manifest["mcp"]["version"]}, installed #{installed}#{asked}",
                                   gem_diff)

    puts reports.join("\n")
    if drifted
      puts "upstream:watch: drift above; re-vendor, re-extract or re-read, then rake upstream:pin"
    else
      puts "upstream:watch: everything at its pin"
    end
  end
end
