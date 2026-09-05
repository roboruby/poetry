# frozen_string_literal: true

module Poetry
  # The family's shared version. Every sibling gem pins its Poetry
  # dependencies to exactly this number, and the umbrella's three runtime
  # dependencies follow it, so one `bundle update poetry` moves the set.
  VERSION = "0.1.0"
end
