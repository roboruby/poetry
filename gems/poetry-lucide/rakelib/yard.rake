# frozen_string_literal: true

# Documentation tasks: `yard:doc` builds the API docs from .yardopts;
# `yard:verify` fails on any YARD warning (the documentation standard:
# a malformed tag or unresolvable reference is a review finding).
# Deliberately NOT in the default task - CI wiring is a follow-up.
namespace :yard do
  desc "Build the YARD API docs into doc/"
  task :doc do
    abort "yard doc failed" unless system("bundle exec yard doc")
  end

  desc "Fail on any YARD warning (structural ones allowlisted)"
  task :verify do
    out = `bundle exec yard doc --no-output --no-progress 2>&1`
    warnings = out.lines.grep(/\[warn\]/)
    # Structural warnings YARD cannot express (dynamic superclasses,
    # mixins onto constants outside this gem) - not doc defects.
    allowed = [/Undocumentable superclass/, /Undocumentable mixin/]
    real = warnings.reject { |w| allowed.any? { |a| w.match?(a) } }
    if real.any?
      puts real
      abort "yard:verify: #{real.length} warning(s)"
    end
    puts "yard:verify: clean (#{warnings.length - real.length} allowlisted)"
  end
end
