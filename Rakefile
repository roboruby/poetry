# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create
require "rubocop/rake_task"
# The umbrella lints only its own files, by explicit list and from its own
# config file. A .rubocop.yml at the repository root would push its excludes
# into every gem's RuboCop below it (RuboCop merges a higher-level config's
# Exclude into subprojects), and a bare run from the root would walk the
# gems with the wrong rules.
RuboCop::RakeTask.new do |t|
  t.options = %w[--config .rubocop-umbrella.yml]
  t.patterns = %w[Gemfile Rakefile poetry.gemspec lib test rakelib .githooks/pre-commit]
end
task default: %i[test rubocop yard:verify yard:coverage yard:coverage:all yard:lint]

# The family: every gem's default chain from its own directory and bundle,
# in publish order (the docs engine last; it is not published), then this
# gem. Each gem stays
# its own bundle, so nothing here loads a sibling into this process.
FAMILY = %w[poetry-core poetry-lucide poetry-charts poetry-extract poetry-ui poetry-agent poetry-simple_form
            poetry-docs].freeze

def run_in(dir, *cmd)
  Bundler.with_unbundled_env { system(*cmd, chdir: dir, exception: true) }
end

namespace :family do
  desc "Every gem's default chain, in publish order"
  task :gems do
    FAMILY.each do |gem|
      puts "== #{gem}"
      run_in(File.join(__dir__, "gems", gem), "bundle", "exec", "rake")
    end
  end
end

desc "The whole family: the gems in publish order, then this gem"
task family: %w[family:gems default]
