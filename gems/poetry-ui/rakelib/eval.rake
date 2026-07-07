# frozen_string_literal: true

# Overlay-family arms are authored closed behind their triggers (the honest
# resting DOM), so a naive screenshot shows a lone button. One representative
# reveal interaction per task - run IDENTICALLY on both arms (the judge-
# evidence honesty rule): click the trigger, screenshot whatever results.
# An arm whose trigger does nothing captures that truth. Values are candidate
# trigger texts tried in order (both arms' spellings).
POETRY_EVAL_REVEAL = {
  "dialog" => ["Settings"],
  "overlay" => ["Delete API key"],
  "mobile_sheet" => ["Set goal"],
  "menu" => ["Options"],
  "searchable_select" => ["Select framework", "Next.js"],
  "site_nav" => ["Products"],
  "date_field" => ["June 12, 2026", "Pick a date"],
  "floating" => ["Open popover"]
}.freeze

# Tags preferred on text-length ties when picking the reveal trigger.
POETRY_EVAL_INTERACTIVE_TAGS = %w[button summary a].freeze

# The innermost visible element carrying the trigger text: matches include
# every wrapper whose text contains the needle, so take the shortest text
# (most specific), preferring real interactive tags on ties. Falls back to
# input values (a raw arm's readonly-input trigger).
def poetry_ui_eval_reveal_target(session, candidates)
  candidates.each do |needle|
    matches = session.all("button, summary, a, [role=button], [onclick], span, div",
                          text: needle, visible: true, wait: 2)
    if matches.any?
      return matches.min_by { |el| [el.text.length, POETRY_EVAL_INTERACTIVE_TAGS.index(el.tag_name) || 9] }
    end

    input = session.all("input", visible: true, wait: 0).find { |el| el.value.to_s.include?(needle) }
    return input if input
  end
  nil
end

def poetry_ui_eval_reveal(session, task)
  candidates = POETRY_EVAL_REVEAL[task]
  return if candidates.nil?

  target = poetry_ui_eval_reveal_target(session, candidates)
  if target.nil?
    puts "  (#{task}: no visible trigger matching #{candidates.inspect} - captured at rest)"
    return
  end
  begin
    target.click
    sleep 0.5 # floating-ui positioning settles; reduced-motion killed the animations
  rescue StandardError => e
    puts "  (#{task}: reveal click failed - #{e.class}: #{e.message} - captured at rest)"
  end
end

namespace :eval do
  desc "Screenshot every frozen eval arm through the browser rig (the golden-baseline " \
       "settings: light, #{POETRY_BROWSER_VIEWPORT.join("x")}) into eval/captures/ - " \
       "the judge's evidence (not in the default gate - needs Chrome)"
  task capture: :"browser:assets" do
    require_relative "../eval/runner"
    require "fileutils"

    session = poetry_ui_browser_session
    runner = Poetry::Eval::Runner.new
    count = 0

    Poetry::Eval::Runner::TASKS.keys.sort.each do |task|
      dir = Poetry::Ui.root.join("eval/captures", task)
      FileUtils.mkdir_p(dir)
      runner.arms(task).keys.sort.each do |arm|
        poetry_ui_visit_preview(session, "/eval/#{task}/#{arm}")
        poetry_ui_eval_reveal(session, task)
        session.driver.save_screenshot(dir.join("#{arm}.png").to_s, full: true)
        count += 1
      end
    end
    puts "eval capture: #{count} screenshots in eval/captures/ " \
         "(#{Poetry::Eval::Runner::TASKS.size} tasks, viewport #{POETRY_BROWSER_VIEWPORT.join("x")})"
  end

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
