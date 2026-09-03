# frozen_string_literal: true

source "https://rubygems.org"

eval_gemfile File.expand_path("Gemfile.shared", __dir__)

# The poetry family at the released version - one number, kept in
# .poetry-version and checked by test/poetry_version_test.rb. The umbrella
# brings poetry-core, poetry-ui and poetry-lucide; the opt-in gems ride the
# same version because every gem pins its siblings exactly. This is the
# bundle CI, fresh clones and deploys resolve; on a machine with the family
# checked out beside this repo, config/boot.rb selects Gemfile.siblings
# instead so the site runs the working trees unpinned.
poetry_version = File.read(File.expand_path(".poetry-version", __dir__)).strip
gem "poetry", poetry_version
gem "poetry-charts", poetry_version
gem "poetry-agent", poetry_version # the MCP server exe + the WebMCP runtime
