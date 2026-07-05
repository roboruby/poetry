# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create do |t|
  # Load test_helper as the framework so SimpleCov starts before
  # minitest/autorun (see poetry-core's Rakefile for the why).
  t.framework = %(require "test_helper")
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]
