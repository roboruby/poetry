# frozen_string_literal: true

# Documentation gates: `yard:doc` builds the API docs; `yard:verify` fails
# on any YARD warning (a malformed tag or unresolvable reference is a
# review finding; structural warnings are allowlisted); `yard:coverage`
# is the ratchet - the committed .yard_coverage floor may only go down
# (lower it deliberately with yard:coverage:record after a documentation
# pass). verify + coverage run in the default task.
namespace :yard do
  undocumented_count = lambda do
    out = `bundle exec yard stats --no-progress 2>&1`
    out.scan(/\(\s*(\d+) undocumented\)/).sum { |(n)| n.to_i }
  end

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
    real = warnings.reject { |warning| allowed.any? { |pattern| warning.match?(pattern) } }
    if real.any?
      puts real
      abort "yard:verify: #{real.length} warning(s)"
    end
    puts "yard:verify: clean (#{warnings.length - real.length} allowlisted)"
  end

  desc "Fail when undocumented-object count exceeds the recorded floor"
  task :coverage do
    abort "yard:coverage: no .yard_coverage - run yard:coverage:record" unless File.exist?(".yard_coverage")
    floor = File.read(".yard_coverage").to_i
    count = undocumented_count.call
    abort "yard:coverage: #{count} undocumented objects (floor #{floor})" if count > floor
    puts "yard:coverage: #{count} undocumented (floor #{floor})"
  end

  namespace :coverage do
    desc "Record the current undocumented-object count as the floor"
    task :record do
      count = undocumented_count.call
      File.write(".yard_coverage", "#{count}\n")
      puts "recorded floor: #{count}"
    end
  end
end
