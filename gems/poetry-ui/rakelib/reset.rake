# frozen_string_literal: true

# The reset floor (lib/poetry/ui/reset_floor.rb): Tailwind's preflight at
# zero specificity, generated from the pinned tailwindcss binary.
namespace :reset do
  desc "Regenerate reset/reset.css from the pinned tailwindcss binary's preflight"
  task :generate do
    require "poetry/ui"
    puts "regenerated #{Poetry::Ui::ResetFloor.generate!}"
  end

  desc "Fail if the committed reset floor does not match the pinned preflight (the CI drift gate)"
  task :verify do
    require "poetry/ui"
    if Poetry::Ui::ResetFloor.verified?
      puts "reset floor in sync (#{Poetry::Ui::ResetFloor::RELATIVE_PATH})"
    else
      abort "stale reset floor - run `bin/rake reset:generate` and commit"
    end
  end
end
