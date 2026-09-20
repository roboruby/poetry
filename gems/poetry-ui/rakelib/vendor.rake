# frozen_string_literal: true

# The dommy tier runs poetry's controllers against Stimulus' UMD build. Side
# by side that build is poetry-core's npm dist; an installed gem has no
# node_modules, so the same build is vendored as a test asset
# (test/dummy/public/vendor). These tasks keep the two in step:
# vendor:stimulus refreshes the asset from the sibling's dist and records the
# version, vendor:stimulus:verify (default chain) fails when they differ and
# skips, with the reason, when no sibling dist exists (CI, a lone clone).
def poetry_ui_vendored_stimulus = Pathname.new(File.expand_path("../test/dummy/public/vendor/stimulus.umd.js", __dir__))

def poetry_ui_vendored_versions = poetry_ui_vendored_stimulus.dirname.join("VENDORED_VERSIONS")

# [dist path, package version] from poetry-core's node_modules, or nil.
def poetry_ui_sibling_stimulus
  require "json"
  package = Poetry::Core.root.join("node_modules/@hotwired/stimulus")
  dist = package.join("dist/stimulus.umd.js")
  return unless dist.exist?

  [dist, JSON.parse(package.join("package.json").read)["version"]]
end

namespace :vendor do
  desc "Refresh the vendored Stimulus UMD test asset from poetry-core's npm dist and record its version"
  task :stimulus do
    poetry_ui_boot!
    dist, version = poetry_ui_sibling_stimulus
    abort "vendor:stimulus needs poetry-core's node_modules (the sibling checkout after npm install)" unless dist

    FileUtils.cp(dist, poetry_ui_vendored_stimulus)
    lines = poetry_ui_vendored_versions.read.lines
    lines.map! do |line|
      line.start_with?("@hotwired/stimulus ") ? "@hotwired/stimulus #{version} (dist/stimulus.umd.js)\n" : line
    end
    poetry_ui_vendored_versions.write(lines.join)
    puts "vendored Stimulus #{version} into test/dummy/public/vendor/stimulus.umd.js"
  end

  namespace :stimulus do
    desc "Fail if the vendored Stimulus UMD test asset differs from poetry-core's npm dist (skips without one)"
    task :verify do
      poetry_ui_boot!
      dist, version = poetry_ui_sibling_stimulus
      unless dist
        puts "vendor: no poetry-core node_modules here (released gem, or no npm install) - Stimulus test asset " \
             "check skipped; it runs side by side"
        next
      end

      recorded = poetry_ui_vendored_versions.read[%r{^@hotwired/stimulus (\S+)}, 1]
      same_bytes = FileUtils.compare_file(dist, poetry_ui_vendored_stimulus)
      if same_bytes && recorded == version
        puts "vendored Stimulus test asset matches poetry-core's dist (#{version})"
      else
        abort "vendored Stimulus test asset drifted from poetry-core's dist #{version} " \
              "(recorded #{recorded.inspect}, bytes #{same_bytes ? "match" : "differ"}) - " \
              "run `bundle exec rake vendor:stimulus` and commit"
      end
    end
  end
end
