# frozen_string_literal: true

namespace :poetry do
  namespace :design do
    desc "Extract a DESIGN.md + design tokens from a public website " \
         "(poetry:design:extract[stripe.com]); hand the result to poetry:design:import"
    task :extract, [:domain] do |_task, args|
      abort "usage: bin/rails \"poetry:design:extract[domain.com]\"" if args[:domain].to_s.empty?

      Poetry::Extract::Runner.run!(args[:domain])
    end
  end
end
