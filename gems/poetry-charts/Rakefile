# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create do |t|
  # Load test_helper as the framework so SimpleCov starts before
  # minitest/autorun (see poetry-core's Rakefile for the why).
  t.framework = %(require "test_helper")
  # The dommy tier (test/dommy_tier) has its own helper and task
  # (test:dommy, rakelib/dommy.rake) - kept out of the unit globs so the
  # default gate doesn't run it twice.
  t.test_globs = ["test/{components,poetry}/**/*_test.rb"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

# css:verify_theme (N12) is compile-free (no tailwindcss binary), so it can
# ride the default gate; css:verify_compiled stays explicit like the
# browser suites.
task default: %i[test test:dommy rubocop css:verify_theme css:verify_rendered]
