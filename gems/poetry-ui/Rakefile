# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create do |t|
  # test_helper loads SimpleCov before minitest/autorun (see poetry-core).
  t.framework = %(require "test_helper")
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop registry:verify]
