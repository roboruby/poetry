# frozen_string_literal: true

module Poetry
  module Ui
    # The cold-start prompt: the first message for an assistant that has
    # none of poetry's surfaces in front of it yet - no AGENTS.md section,
    # no skill, no MCP server (a hosted agent, a teammate's editor before
    # `poetry:skill` ran). It verifies the install, routes to the surfaces
    # the install wrote, carries the usage rules every llms.txt prints and
    # ends on check-LAST. One text: `bin/rails poetry:prompt` prints it
    # (pipe it to the clipboard) and the docs site's Installation page
    # shows it.
    module Prompt
      # The prompt text, ready to paste.
      #
      # @return [String]
      def self.cold_start
        rules = Poetry::Core::LlmsText::USAGE_RULES.map { |rule| "   - #{rule}" }.join("\n")
        <<~PROMPT
          This Rails app uses Poetry, a component library with its own agent surface. Before any UI work:

          1. Read the "Building UI with poetry" section of AGENTS.md. Load the `poetry` skill under .claude/skills/ whenever you write ERB, `poetry-design` before composing a page or screen, and `poetry-component` when authoring an app-owned component. If .claude/skills/poetry/ is missing, run `bin/rails g poetry:skill` first.
          2. Verify the install before adding anything: `bin/rails poetry:verify` (component classes against the compiled CSS, the committed app registry and controllers manifest) and `bin/rails poetry:check` over the current templates. Fix what they report before your own work.
          3. Usage rules:
          #{rules}
          4. The catalog: /poetry/llms.txt (index and blocks) and /poetry/llms-full.txt (full contracts and Stimulus wiring) on this app, or the poetry MCP server when poetry-agent is bundled (`bin/rails g poetry:editor` wires it into every editor) - prefer its `compose` tool to start and its `check` tool while iterating.
          5. Check comes LAST: run `bin/rails poetry:check` as your final action, after your last edit, and report what it found.
        PROMPT
      end
    end
  end
end
