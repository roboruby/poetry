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

  # yard-lint over the documented surface. YARD hides @api private objects
  # from the reference (--hide-api private in .yardopts) and yard:coverage
  # counts only what the reference shows; yard-lint has no such switch, so
  # its offenses are filtered here against the YARD registry: an offense on
  # an object inside an @api private class or module is not a finding.
  desc "Fail on any yard-lint offense on the documented surface (missing @param lines, tag order, types)"
  task :lint do
    require "json"
    require "yard"
    system("bundle exec yard doc --no-output --no-progress --no-stats > /dev/null 2>&1")
    YARD::Registry.load!(".yardoc")
    private_api = lambda do |object|
      node = object
      until node.nil? || node.root?
        return true if node.has_tag?(:api) && node.tag(:api).text == "private"

        node = node.namespace
      end
      false
    end
    by_location = YARD::Registry.all.select(&:file).to_h { |o| [[File.expand_path(o.file.to_s), o.line], o] }
    raw = `bundle exec yard-lint --no-progress --format json lib app 2>/dev/null`
    start = raw.index(/[\[{]/) or abort "yard:lint: no JSON from yard-lint"
    offenses = JSON.parse(raw[start..]).fetch("offenses", [])
    surface = offenses.reject do |o|
      object = by_location[[File.expand_path(o["location"]), o["line"]]]
      object && private_api.call(object)
    end
    hidden = "#{offenses.size - surface.size} inside @api private, not counted"
    if surface.any?
      surface.each do |o|
        puts "#{o["location"].sub("#{Dir.pwd}/", "")}:#{o["line"]} #{o["validator"]}: #{o["message"]}"
      end
      abort "yard:lint: #{surface.size} offense(s) on the documented surface (#{hidden})"
    end
    puts "yard:lint: clean (#{hidden})"
  end

  # The whole tree, private methods and the api-private internals included:
  # every class, module and method counts as undocumented when its
  # docstring has no sentence (a tag alone is not documentation). The
  # committed .yard_coverage_all floor ratchets the same way.
  whole_tree_undocumented = lambda do
    require "yard"
    system("bundle exec yard doc --no-output --no-progress --no-stats > /dev/null 2>&1")
    YARD::Registry.load!(".yardoc")
    YARD::Registry.all(:class, :module, :method).count { |object| object.docstring.to_s.strip.empty? }
  end

  namespace :coverage do
    desc "Record the current undocumented-object count as the floor"
    task :record do
      count = undocumented_count.call
      File.write(".yard_coverage", "#{count}\n")
      puts "recorded floor: #{count}"
    end

    desc "Fail when the whole-tree undocumented count (private and internal included) exceeds the recorded floor"
    task :all do
      unless File.exist?(".yard_coverage_all")
        abort "yard:coverage:all: no .yard_coverage_all - run yard:coverage:all:record"
      end

      floor = File.read(".yard_coverage_all").to_i
      count = whole_tree_undocumented.call
      abort "yard:coverage:all: #{count} objects without a sentence (floor #{floor})" if count > floor
      puts "yard:coverage:all: #{count} without a sentence (floor #{floor})"
    end

    namespace :all do
      desc "Record the current whole-tree undocumented count as the floor"
      task :record do
        count = whole_tree_undocumented.call
        File.write(".yard_coverage_all", "#{count}\n")
        puts "recorded whole-tree floor: #{count}"
      end
    end
  end
end
