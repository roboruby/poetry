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

# The coverage ratchet: .yard_coverage records the accepted number of
# undocumented objects; the gate fails when the count grows. Lowering the
# floor is deliberate - run yard:coverage:record after a documentation pass.
namespace :yard do
  def yard_undocumented_count
    out = `bundle exec yard stats --no-progress 2>&1`
    out.scan(/\(\s*(\d+) undocumented\)/).flatten.map(&:to_i).sum
  end

  desc "Fail when undocumented-object count exceeds the recorded floor"
  task :coverage do
    floor_file = ".yard_coverage"
    abort "yard:coverage: no #{floor_file} - run yard:coverage:record" unless File.exist?(floor_file)
    floor = File.read(floor_file).to_i
    count = yard_undocumented_count
    abort "yard:coverage: #{count} undocumented objects (floor #{floor})" if count > floor
    puts "yard:coverage: #{count} undocumented (floor #{floor})"
  end

  namespace :coverage do
    desc "Record the current undocumented-object count as the floor"
    task :record do
      count = yard_undocumented_count
      File.write(".yard_coverage", "#{count}\n")
      puts "recorded floor: #{count}"
    end
  end
end
