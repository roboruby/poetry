# frozen_string_literal: true

require_relative "../lib/poetry/ui/theme_fidelity"
require_relative "../lib/poetry/ui/dictionary_fidelity"

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

  desc "Report what changed upstream between two pins (the pin-bump ceremony's first step; " \
       "OLD=<ref> NEW=<ref>, tags welcome; read-only)"
  task :upstream_delta do
    old_ref = ENV.fetch("OLD", nil) or abort "OLD=<ref> required"
    new_ref = ENV.fetch("NEW", nil) or abort "NEW=<ref> required"
    sh "bundle", "exec", "ruby", File.expand_path("../script/upstream_delta.rb", __dir__), old_ref, new_ref
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

  desc "Regenerate the frozen source snapshot of per-slot classNames (pin-bump ceremony; " \
       "needs UPSTREAM=<checkout> PIN=<sha>)"
  task :dictionary_snapshot do
    checkout = ENV.fetch("UPSTREAM", nil) or abort "UPSTREAM=<path to the pinned checkout> required"
    pin = ENV.fetch("PIN", nil) or abort "PIN=<sha> required"
    old = Dir.glob(File.expand_path("../config/dictionary_fidelity/upstream-*.json", __dir__))
    path = Poetry::Ui::DictionaryFidelity.write_snapshot(File.expand_path("..", __dir__), checkout: checkout, pin: pin)
    (old - [path]).each { |stale| File.delete(stale) }
    puts "wrote #{path} - now re-review the diff and re-reason config/dictionary_fidelity/deviations.yml"
  end

  desc "Every dictionary's diff against its pinned source must match config/dictionary_fidelity/deviations.yml " \
       "exactly (renders every preview; also writes tmp/dictionary_fidelity/diffs.json)"
  task :verify_dictionary_fidelity do
    sh({ "DICTIONARY_REPORT" => "1" }, "bundle", "exec", "ruby", "-Itest",
       File.expand_path("../test/poetry/ui/dictionary_fidelity_test.rb", __dir__))
  end
end
