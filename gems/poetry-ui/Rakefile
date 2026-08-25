# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create do |t|
  # test_helper loads SimpleCov before minitest/autorun (see poetry-core).
  t.framework = %(require "test_helper")
  # The dommy tier (test/dommy_tier) has its own helper and task
  # (test:dommy, rakelib/dommy.rake) - kept out of the unit globs so the
  # default gate doesn't run it twice.
  t.test_globs = ["test/{components,generators,poetry}/**/*_test.rb"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test test:dommy rubocop registry:verify css:template_classes:verify css:verify_compiled
                 css:verify_selected_bridge css:verify_reduced_motion css:verify_theme css:verify_fidelity
                 css:verify_rendered
                 css:verify_hooks css:verify_vars design:verify
                 eval:verify goldens:verify_inputs yard:verify yard:coverage]
