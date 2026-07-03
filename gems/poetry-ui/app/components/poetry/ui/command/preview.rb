# frozen_string_literal: true

module Poetry
  module Ui
    module Command
      # The Command preview matrix: the shadcn command-demo composition
      # (inline, groups + shortcuts + keywords), the ⌘K dialog variant,
      # the zero-match empty state, disabled items, the filter:false
      # server mode, an initial value: highlight, and RTL.
      class Preview < Poetry::Core::Preview::Base
        # The command-demo port: grouped commands with shortcuts; Calendar
        # carries keywords ("schedule" finds it), Calculator is disabled.
        # Type to filter live; a non-matching query shows the empty part
        # and announces "0 results".
        def default
          render_component(placeholder: "Type a command or search...",
                           "aria-label": "Command palette",
                           class: "rounded-lg border shadow-md") do |command|
            command.with_group(heading: "Suggestions") do |group|
              group.with_item(value: "calendar", keywords: %w[schedule dates]) { "Calendar" }
              group.with_item(value: "emoji") { "Search Emoji" }
              group.with_item(value: "calculator", disabled: true) { "Calculator" }
            end
            command.with_separator
            command.with_group(heading: "Settings") do |group|
              group.with_item(value: "profile", shortcut: "⌘P") { "Profile" }
              group.with_item(value: "billing", shortcut: "⌘B") { "Billing" }
              group.with_item(value: "settings", shortcut: "⌘S") { "Settings" }
            end
          end
        end

        # command-dialog parity: the ⌘K palette - the trigger button (and
        # the opt-in meta+k hotkey) open the Dialog; focus lands in the
        # input; Esc closes via the platform dialog.
        def dialog
          render(Poetry::Ui::Command::DialogComponent.new(hotkey: "meta+k",
                                                          placeholder: "Type a command or search...")) do |palette|
            palette.with_trigger(variant: :outline) { "Open command palette (⌘K)" }
            palette.with_group(heading: "Suggestions") do |group|
              group.with_item(value: "calendar") { "Calendar" }
              group.with_item(value: "emoji") { "Search Emoji" }
            end
            palette.with_separator
            palette.with_group(heading: "Settings") do |group|
              group.with_item(value: "profile", shortcut: "⌘P") { "Profile" }
              group.with_item(value: "settings", shortcut: "⌘S") { "Settings" }
            end
          end
        end

        # The zero-match state: type any non-matching query ("zzz") - every
        # item hides, the custom empty part shows, and the status region
        # announces "0 results". The pinned group survives via
        # always_render (cmdk forceMount).
        def zero_match
          render_component("aria-label": "Jump to", placeholder: "Search pages…",
                           class: "rounded-lg border shadow-md") do |command|
            command.with_empty { "Nothing matches - try fewer letters." }
            command.with_item(value: "dashboard") { "Dashboard" }
            command.with_item(value: "reports") { "Reports" }
            command.with_group(heading: "Recent", always_render: true) do |group|
              group.with_item(value: "readme", always_render: true) { "README.md" }
            end
          end
        end

        # Disabled items: skipped by arrows and the filter re-seat; the
        # first ENABLED item takes the server-rendered initial highlight.
        def disabled_items
          render_component("aria-label": "Actions", class: "rounded-lg border shadow-md") do |command|
            command.with_item(value: "cut", disabled: true) { "Cut" }
            command.with_item(value: "copy") { "Copy" }
            command.with_item(value: "paste", disabled: true) { "Paste" }
            command.with_item(value: "delete") { "Delete" }
          end
        end

        # An initial value: highlight, server-rendered (data-highlighted +
        # the input's aria-activedescendant point at Billing before any JS).
        def valued
          render_component(value: "billing", "aria-label": "Settings",
                           class: "rounded-lg border shadow-md") do |command|
            command.with_item(value: "profile") { "Profile" }
            command.with_item(value: "billing") { "Billing" }
            command.with_item(value: "notifications") { "Notifications" }
          end
        end

        # filter: false - the SERVER-DRIVEN mode (cmdk shouldFilter=false):
        # typing never hides items client-side; the host re-renders the
        # list (Turbo frame ?q=) and Command keeps highlight + activation +
        # the count announcement. The loading part is the host-toggled
        # pending affordance.
        def server_mode
          render_component(filter: false, "aria-label": "Search records",
                           placeholder: "Search customers…",
                           class: "rounded-lg border shadow-md") do |command|
            command.with_loading { "Searching…" }
            command.with_item(value: "acme") { "Acme Corp" }
            command.with_item(value: "globex") { "Globex" }
            command.with_item(value: "initech") { "Initech" }
          end
        end

        # dir=rtl: the search icon leads via flex order, the shortcut's
        # ms-auto keeps it on the reading-order end (the logical-property
        # fix over the source's ml-auto).
        def rtl
          render_component(dir: :rtl, "aria-label": "الأوامر", list_label: "الأوامر",
                           placeholder: "ابحث عن أمر…", class: "rounded-lg border shadow-md") do |command|
            command.with_group(heading: "اقتراحات") do |group|
              group.with_item(value: "calendar", shortcut: "⌘C") { "التقويم" }
              group.with_item(value: "search") { "بحث" }
            end
          end
        end
      end
    end
  end
end
