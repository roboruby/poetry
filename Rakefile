# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create
require "rubocop/rake_task"
# The umbrella lints only its own files, by explicit list and from its own
# config file. A .rubocop.yml at the repository root would push its excludes
# into every gem's RuboCop below it (RuboCop merges a higher-level config's
# Exclude into subprojects), and a bare run from the root would walk the
# gems and the site with the wrong rules.
RuboCop::RakeTask.new do |t|
  t.options = %w[--config .rubocop-umbrella.yml]
  t.patterns = %w[Gemfile Rakefile poetry.gemspec lib test rakelib]
end
task default: %i[test rubocop yard:verify yard:coverage yard:coverage:all yard:lint]
