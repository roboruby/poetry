# frozen_string_literal: true

namespace :eval do
  desc "Run the eval harness (frozen task arms, deterministic gates) and emit the scorecard"
  task :scorecard do
    poetry_ui_boot!
    require_relative "../eval/runner"

    card, path = Poetry::Eval::Runner.new.write!
    card["tasks"].each do |task, spec|
      puts "#{task}: #{spec["description"]}"
      spec["arms"].each do |arm, result|
        gates = result["cross_arm"].map { |gate, pass| "#{pass ? "+" : "-"}#{gate}" }.join(" ")
        puts "  #{arm.ljust(14)} cross-arm #{result["cross_arm_score"]}  #{gates}"
        if (diag = result["poetry_only_diagnostics"])
          puts "  #{" ".ljust(14)} diagnostics    #{diag.map { |gate, pass| "#{pass ? "+" : "-"}#{gate}" }.join(" ")}"
        end
      end
    end
    puts "components exercised: #{card["components_exercised"].join(", ")}"
    puts "scorecard: #{path}"
  end
end
