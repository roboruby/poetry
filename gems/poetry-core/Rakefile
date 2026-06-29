# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create do |t|
  # Load test_helper as the framework so SimpleCov starts (and registers its
  # at_exit) *before* minitest/autorun — otherwise coverage is collected before
  # the tests run and under-reports anything autoloaded during execution.
  t.framework = %(require "test_helper")
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]
