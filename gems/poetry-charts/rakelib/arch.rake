# frozen_string_literal: true

# Architecture gates, in the default task. arch:check runs the ArchSpec
# spec (Archspec.rb: the dependency rules the family enforces by review,
# checked from source without booting). arch:order checks the order inside
# every component class - declarations first, then methods, neither
# interrupting the other (AGENTS.md). arch:lint, where a gem carries rules
# under rubydex_linter/rules, runs them through the Rubydex linter.
namespace :arch do
  desc "Check the architecture spec (Archspec.rb)"
  task :check do
    abort "arch:check: violations above" unless system("bundle exec archspec check")
  end

  desc "Check the order inside every component class: declarations first, then methods"
  task :order do
    declaration = /\A\s*(style|option|renders_one|renders_many|part|use_stimulus|tool|helper|validates|requires_content|
                      internal_component!|css_mode|delegate|attr_\w+|class_attribute|include|extend|alias)\b/x
    findings = []
    Dir.glob("app/components/**/*.rb").each do |file|
      lines = File.readlines(file)
      lines.each_with_index do |line, start|
        next unless line =~ /^( *)class \w+ < /

        indent = Regexp.last_match(1).size
        body = indent + 2
        seen_def = nil
        ((start + 1)...lines.size).each do |i|
          current = lines[i]
          break if /^ {#{indent}}end\b/.match?(current)
          next unless current[/^ */].size == body
          break if /^\s*private\s*$/.match?(current)

          if current =~ /^\s*def (\w+[?!=]?)/
            seen_def ||= [Regexp.last_match(1), i + 1]
          elsif current =~ declaration && seen_def
            name = current.strip[/\A\w+!?/]
            # A class-method hook an include consumes must exist before that include.
            next if name == "include" && lines[seen_def[1] - 1].include?("def self.")

            findings << "#{file}:#{i + 1}: #{name} declared after the method #{seen_def[0]} (line #{seen_def[1]})"
            break
          end
        end
      end
    end
    abort "arch:order:\n  #{findings.join("\n  ")}" if findings.any?
    puts "arch:order: declarations first in every component class"
  end

  desc "Run the gem's Rubydex linter rules (rubydex_linter/rules)"
  task :lint do
    next puts("arch:lint: no rules in rubydex_linter/rules") unless Dir.exist?("rubydex_linter/rules")

    abort "arch:lint: findings above" unless system("bundle exec rdx lint")
  end
end
