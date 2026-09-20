# frozen_string_literal: true

require "minitest/test_task"

# The dommy middle tier (the poetry-ui pattern): the real chart
# controllers - vendored d3 kernel and live renderer included - headlessly
# in Minitest on QuickJS, no browser. Sits between `rake test`
# (rendered-HTML assertions) and the real-browser pass (test:accessibility /
# test:visual), so it joins the default gate. Its own helper
# (test/dommy_tier/dommy_helper) boots the dummy host + dommy directly.
Minitest::TestTask.create(:"test:dommy") do |t|
  t.test_globs = ["test/dommy_tier/**/*_test.rb"]
  t.framework = %(require "dommy_tier/dommy_helper")
end
