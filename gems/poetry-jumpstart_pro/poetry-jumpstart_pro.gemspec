# frozen_string_literal: true

require_relative "lib/poetry/jumpstart_pro/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-jumpstart_pro"
  spec.version = Poetry::JumpstartPro::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "Re-skin a Jumpstart Pro app with Poetry components."
  spec.description = "An installer that replaces a Jumpstart Pro app's views with Poetry-native " \
                     "recreations, accessible, themeable and agent-legible, and reconciles Jumpstart's " \
                     "stylesheets with Poetry's tokens. Ships only Poetry views, never Jumpstart's source, " \
                     "and installs them as host app/views overrides."
  spec.homepage = "https://poetryui.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"
  spec.metadata["homepage_uri"] = "https://poetryui.com"
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry/tree/main/gems/poetry-jumpstart_pro"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry/blob/main/gems/poetry-jumpstart_pro/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/roboruby/poetry/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE.txt", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 8.0"
  # The family releases in lockstep, so the siblings are exact pins. The
  # installed views render on poetry-ui's helpers and form builder and draw
  # poetry-lucide's icons.
  spec.add_dependency "poetry-core", "= #{Poetry::JumpstartPro::VERSION}"
  spec.add_dependency "poetry-lucide", "= #{Poetry::JumpstartPro::VERSION}"
  spec.add_dependency "poetry-ui", "= #{Poetry::JumpstartPro::VERSION}"
end
