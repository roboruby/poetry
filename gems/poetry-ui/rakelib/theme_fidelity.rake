# frozen_string_literal: true

require_relative "../lib/poetry/ui/theme_fidelity"

namespace :css do
  desc "Every ported theme's diff against its pinned source must match config/theme_fidelity/deviations.yml exactly"
  task :verify_fidelity do
    findings = Poetry::Ui::ThemeFidelity.verify(File.expand_path("..", __dir__))
    if findings.any?
      puts findings
      abort "css:verify_fidelity: #{findings.length} finding(s) - reconcile config/theme_fidelity/deviations.yml"
    end
    puts "theme fidelity: all ported themes match the recorded deviation contract"
  end

  desc "Regenerate the frozen source snapshot (pin-bump ceremony; needs UPSTREAM=<checkout> PIN=<sha>)"
  task :fidelity_snapshot do
    checkout = ENV.fetch("UPSTREAM", nil) or abort "UPSTREAM=<path to the pinned checkout> required"
    pin = ENV.fetch("PIN", nil) or abort "PIN=<sha> required"
    old = Dir.glob(File.expand_path("../config/theme_fidelity/upstream-*.json", __dir__))
    path = Poetry::Ui::ThemeFidelity.write_snapshot(File.expand_path("..", __dir__), checkout: checkout, pin: pin)
    (old - [path]).each { |stale| File.delete(stale) }
    puts "wrote #{path} - now re-review the diff and re-reason deviations.yml"
  end
end
