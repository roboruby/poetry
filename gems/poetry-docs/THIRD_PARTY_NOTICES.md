# Third-party notices

The docs site adapts or vendors the following MIT-licensed work. Each entry
names the source and where the copy lives here.

## page-agent

- Source: https://github.com/alibaba/page-agent
- License: MIT
- Copy: `public/vendor/page-agent/page-agent-1.12.2.js` (vendored, unmodified), embedded by the `/page-agent` guide's operator-register demo.

## shadcn/ui (the Trace chat example)

- Source: https://github.com/shadcn-ui/ui at shadcn@4.23.0, `apps/v4/registry/bases/base/examples/trace-example.tsx` (its chat: `groupParts`, `ReasoningActivity`, `ToolRow`, `ActivityRow`, `ToolApproval`, `ToolInputOutput`)
- License: MIT
- Copy: adapted to Ruby and ERB in `app/lib/poetry/docs/agent_activity.rb` and `app/views/poetry/docs/agent_activity/`, which render the AG-UI Relay and Chat Replay demos' reasoning, tool calls and approvals.

## Octicons (GitHub's mark)

- Source: https://github.com/primer/octicons (the `mark-github` 16px path)
- License: MIT
- Copy: the inline SVG in `app/views/shared/_project_links.html.erb`, used as the icon of the link to the project's GitHub repository. GitHub's logo usage guidelines permit the mark for linking to GitHub.
