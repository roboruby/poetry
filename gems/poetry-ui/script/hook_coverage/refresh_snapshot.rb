# frozen_string_literal: true

# Regenerates config/upstream_hooks.txt from the saved shadcn clone - run at
# delta checks (NOT in CI; the snapshot is committed). The inventory is every
# cn-* class selector across the eight upstream theme dictionaries, -aria
# variants excluded (poetry ports the base variant).
#
#   ruby script/hook_coverage/refresh_snapshot.rb [path-to-clone]

clone = ARGV[0] || File.expand_path("~/Desktop/save/shadcn-ui")
themes = %w[luma lyra maia mira nova rhea sera vega]
hooks = themes.flat_map do |t|
  `cd #{clone} && git show origin/main:apps/v4/registry/styles/style-#{t}.css`
    .scan(/^\s*\.(cn-[a-z0-9-]+)/).flatten
end.uniq.sort.reject { |h| h.end_with?("-aria") }

File.write(File.expand_path("../../config/upstream_hooks.txt", __dir__), hooks.join("\n") + "\n")
puts "#{hooks.size} hooks -> config/upstream_hooks.txt"
