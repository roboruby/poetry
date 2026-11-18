# frozen_string_literal: true

# The cold-start prompt for an assistant that has none of poetry's
# surfaces in front of it yet: `bin/rails poetry:prompt | pbcopy`, then
# paste it as the first message. No app boot - the text is static.
# Loaded automatically by the engine (lib/tasks).
namespace :poetry do
  desc "Print the cold-start prompt for an assistant without the poetry skills or MCP server " \
       "(`| pbcopy` copies it)"
  task :prompt do
    puts Poetry::Ui::Prompt.cold_start
    if $stdout.tty?
      warn "poetry:prompt: paste the text above as the first message - " \
           "`bin/rails poetry:prompt | pbcopy` copies it"
    end
  end
end
