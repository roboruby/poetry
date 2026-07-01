# frozen_string_literal: true

namespace :tokens do
  desc "Regenerate tokens/tokens.css, tokens/tailwind-theme.css, and the DESIGN.md front matter " \
       "from tokens/tokens.dtcg.json"
  task :generate do
    require_relative "../lib/poetry/core"
    written = Poetry::Core::Tokens::Generator.new.generate!
    puts(written.map { |path| "regenerated #{path}" })
  end

  desc "Fail if any generated token artifact is stale relative to tokens/tokens.dtcg.json (the CI drift gate)"
  task :verify do
    require_relative "../lib/poetry/core"
    stale = Poetry::Core::Tokens::Generator.new.verify
    if stale.empty?
      puts "token artifacts in sync (#{Poetry::Core::Tokens::Generator::ARTIFACTS.join(", ")})"
    else
      abort "stale token artifacts: #{stale.join(", ")} - run `bin/rake tokens:generate` and commit"
    end
  end
end
