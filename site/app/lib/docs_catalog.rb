# The single source for what the site documents: both gem registries -
# the same files the gems' CI drift-gates - drive the sidebar, the command
# palette, and the routable slugs. Nothing here is hand-maintained; a new
# component appears in the nav the moment its gem registers it.
class DocsCatalog
  Entry = Struct.new(:slug, :title, :section, :description, :icon, keyword_init: true) do
    # Docs guides are top-level routes (/theming, /typography); the gallery
    # sections nest under their section prefix.
    def path = section == "docs" ? "/#{slug}" : "/#{section}/#{slug}"
  end

  # Chart chrome components documented THROUGH the family pages, not as
  # their own entries.
  CHART_CHROME = %w[container legend_content tooltip_content tooltip_layer].freeze

  # Hand-curated guide pages: cross-component content no single registry
  # entry owns. Each has its own controller action; entries here feed the
  # sidebar, the palette, the search index, and the 200-gate.
  DOCS = [
    Entry.new(slug: "installation", title: "Installation", section: "docs", icon: :package,
              description: "Install and upgrade: what poetry:install wires (idempotent, theme-sticky " \
                           "re-runs), the three ownership tiers, and the poetry:diff copy-in report — " \
                           "the install generator is the upgrade path, not a one-shot."),
    Entry.new(slug: "theming", title: "Theming", section: "docs", icon: :palette,
              description: "All nine upstream themes: install-time selection with --theme, the " \
                           "docs style switcher mechanism, and the lyra/sera font-pairing story."),
    Entry.new(slug: "typography", title: "Typography", section: "docs", icon: :type,
              description: "Heading, paragraph, list, table, and inline-text recipes on poetry " \
                           "tokens — class strings transcribed from upstream at the pin. Fonts " \
                           "ride the theme: the same markup goes mono under lyra, serif under sera."),
    Entry.new(slug: "deferred", title: "Deferred Regions", section: "docs", icon: :timer,
              description: "poetry_deferred(src:) — Turbo owns the loading physics (lazy fetches " \
                           "on visibility, so hidden Tabs panels and HoverCards defer for free); " \
                           "poetry owns the states: a Skeleton placeholder and a retryable error card."),
    Entry.new(slug: "optimistic-forms", title: "Optimistic Forms", section: "docs", icon: :zap,
              description: "poetry_optimistic_form — the predicted result paints on submit as a " \
                           "server-authored Turbo Stream; the server corrects only on rejection " \
                           "(morph refresh). One vocabulary for prediction and truth, plus the " \
                           "204/no-redirect server contract."),
    Entry.new(slug: "editors", title: "Editors", section: "docs", icon: :code,
              description: "bin/rails g poetry:editor wires poetry's MCP server and registry-driven " \
                           "snippets into the editors a Rails team uses (VS Code, Cursor, Claude Code, " \
                           "Zed, RubyMine): safe MCP-config upserts, a per-editor matrix, and the " \
                           "Figma / Paper design-tool token bridges.")
  ].freeze

  # The interaction demos are the one hand-curated section: full-page
  # machinery (server round trips, streaming, cross-chart sync) that no
  # single registry component owns.
  DEMOS = [
    Entry.new(slug: "interactive", title: "Interactive Filter", section: "demos",
              description: "Upstream's interactive blocks are useState filters. Here the filter " \
                           "is a real form: submitting re-renders the chart on the server and Turbo " \
                           "swaps it in. Switch the traffic dataset and the chart morphs between " \
                           "renders; switch the period and the entrance replays instead."),
    Entry.new(slug: "live", title: "Live Streaming", section: "demos",
              description: "The server renders the first frame complete; a ticker then streams a " \
                           "sliding window through the payload-script channel and the client kernel " \
                           "redraws — zero further server round trips. Hover while it runs: the " \
                           "tooltip keeps serving fresh values."),
    Entry.new(slug: "sync", title: "Synced Tooltips", section: "demos",
              description: "Two charts share one sync group. Hover or arrow-key either chart and " \
                           "both tooltips follow the same index — recharts' syncId, without a " \
                           "client chart library."),
    Entry.new(slug: "window", title: "Brush & Zoom", section: "demos",
              description: "A year of data behind the window mechanism: drag the brush handles (or " \
                           "the window body) to slice it, drag a range on the plot to zoom in, " \
                           "double-click to reset. Everything recomputes client-side.")
  ].freeze

  # Component one-liners shown under the page title (the shadcn docs pattern).
  # Editorial copy, so hand-authored here rather than registry-derived - a
  # component with no entry just renders without a description (the page view
  # guards on it), so a newly registered component degrades gracefully.
  COMPONENT_DESCRIPTIONS = {
    "accordion" => "A vertically stacked set of interactive headings that each reveal a section of content.",
    "alert" => "A callout that highlights an important inline message.",
    "alert-dialog" => "A modal dialog that interrupts the user and expects a response.",
    "aspect-ratio" => "Locks its content to a fixed width-to-height ratio.",
    "attachment" => "A file or image chip showing its name, type, and size.",
    "avatar" => "A user's image with an initials fallback.",
    "badge" => "A small count or status descriptor.",
    "breadcrumb" => "Shows the path to the current page as a trail of links.",
    "bubble" => "A chat message bubble aligned to its sender.",
    "button" => "Triggers an action or event, such as submitting a form or opening a dialog.",
    "button-group" => "Visually joins adjacent buttons and controls into one group.",
    "calendar" => "A month grid for selecting single dates or ranges.",
    "card" => "A container that groups related content and actions.",
    "carousel" => "A slideshow for cycling through content, built on native scroll-snap.",
    "checkbox" => "A control for toggling a single value on or off.",
    "clipboard-text" => "A read-only value with a button to copy it to the clipboard.",
    "code-block" => "A syntax-highlighted code panel with a copy button and optional line numbers.",
    "collapsible" => "An interactive element that expands and collapses a section of content.",
    "combobox" => "A text input with an autocomplete popover for picking from a list.",
    "command" => "A command palette for fast, keyboard-driven search and actions.",
    "command-dialog" => "The command palette in a modal dialog, summonable from anywhere.",
    "context-menu" => "A menu of actions revealed by right-clicking an element.",
    "data-table" => "A table with sorting, row selection, and sticky headers.",
    "date-field" => "A segmented input for typing a date one part at a time.",
    "date-picker" => "A date field that opens a calendar popover for selection.",
    "deferred" => "A region that lazily loads its content on visibility, with skeleton and error states.",
    "dialog" => "A window overlaid on the page for content that requires attention.",
    "drawer" => "A gesture-driven panel that slides in from a screen edge.",
    "dropdown-menu" => "A menu of actions or options triggered by a button.",
    "empty" => "An empty-state placeholder with an icon, message, and actions.",
    "field" => "Wraps a form control with its label, hint, and validation message.",
    "file-input" => "A control for selecting, previewing, and removing files to upload.",
    "hover-card" => "A card that reveals preview content when its trigger is hovered.",
    "icon" => "Renders an inline SVG icon from the icon set.",
    "input" => "A form control for entering a single line of text.",
    "input-group" => "One bordered surface combining an input with buttons, icons, or add-ons.",
    "input-otp" => "A fixed-length, segmented input for one-time passcodes.",
    "item" => "A generic list row with media, content, and actions.",
    "kbd" => "Displays a keyboard key or shortcut.",
    "label" => "An accessible caption bound to a form control.",
    "link" => "A styled navigational hyperlink.",
    "marker" => "A transcript divider or inline status marker for chat UIs.",
    "menubar" => "A horizontal bar of menus, like a desktop application menu.",
    "message" => "A chat row pairing an author and avatar with message content.",
    "message-scroller" => "A streaming-aware transcript that keeps the latest message in view.",
    "metadata-list" => "A key-value list for labeled attributes on detail pages.",
    "meter" => "A gauge that shows a quantity within a known range.",
    "native-select" => "A styled wrapper around the real native select control.",
    "navigation-menu" => "A site-navigation bar with links and optional dropdown panels.",
    "number-field" => "A numeric input with increment and decrement steppers.",
    "pagination" => "Navigation for moving between pages of content.",
    "popover" => "Rich floating content anchored to a trigger.",
    "progress" => "A determinate progress bar toward task completion.",
    "radio-group" => "A set of options where only one can be selected at a time.",
    "resizable" => "Panels with draggable handles for resizing adjacent regions.",
    "scroll-area" => "A bounded, keyboard-reachable scroll region with styled scrollbars.",
    "search-field" => "A search input with clear and search affordances.",
    "select" => "A dropdown for choosing one option from a list.",
    "sensitive-input" => "A masked secret field with a reveal toggle and a copy button.",
    "separator" => "A thin divider between content, decorative or semantic.",
    "sheet" => "A dialog that slides in from a screen edge.",
    "sidebar" => "A collapsible app-shell navigation column.",
    "skeleton" => "A pulsing placeholder shown while content loads.",
    "slider" => "An input for selecting a value or range along a track.",
    "spinner" => "An indeterminate loading indicator that announces itself.",
    "stat" => "A single KPI: a muted label over a large metric value.",
    "switch" => "A toggle for turning a setting on or off.",
    "table" => "A semantic table for rows and columns of data.",
    "tabs" => "A tablist of triggers that switch between content panels.",
    "tag-group" => "A set of removable chips or tokens.",
    "textarea" => "A form control for entering multiple lines of text.",
    "time-field" => "A segmented input for typing a time one part at a time.",
    "timeline" => "A sequence of dated events as an ordered list.",
    "toast" => "A brief, auto-dismissing notification message.",
    "toaster" => "The region that stacks and manages toast notifications.",
    "toggle" => "A two-state button that can be pressed on or off.",
    "toggle-group" => "A set of toggle buttons for single or multiple selection.",
    "toolbar" => "A horizontal group of controls that acts as one keyboard tab stop.",
    "tooltip" => "A floating label describing an element on hover or focus.",
    "tree" => "A hierarchical list of expandable, selectable nodes.",
    "typeset" => "Prose styling for long-form and rendered-markdown content."
  }.freeze

  class << self
    def components
      @components ||= registry_keys(Poetry::Ui.root).map do |key|
        slug = key.split("/")[2..].join("-").tr("_", "-")
        Entry.new(slug: slug, title: titleize(slug), section: "components",
                  description: COMPONENT_DESCRIPTIONS[slug])
      end.sort_by(&:slug)
    end

    def charts
      @charts ||= registry_keys(Poetry::Charts.root).filter_map do |key|
        name = key.split("/").last
        next if CHART_CHROME.include?(name)

        slug = name.delete_suffix("_chart").tr("_", "-")
        Entry.new(slug: slug, title: "#{titleize(slug)} Chart", section: "charts")
      end.sort_by(&:slug)
    end

    def demos = DEMOS

    def docs = DOCS

    # The blocks gallery (Blocks v1): registry-driven like components - the
    # blocks section of poetry-ui's registry is the roster, so a new block
    # appears in the nav, palette, and 200-gate the moment the gem ships it.
    def blocks
      @blocks ||= blocks_meta.map do |slug, entry|
        Entry.new(slug: slug, title: entry["title"], section: "blocks",
                  description: entry["description"])
      end.sort_by(&:slug)
    end

    # The raw registry entry (template path, composed components) for one
    # block - the block page reads the real source through it.
    def block_meta(slug) = blocks_meta[slug]

    def find(section, slug)
      list = { "charts" => charts, "demos" => demos, "blocks" => blocks }.fetch(section, components)
      list.find { |entry| entry.slug == slug }
    end

    def all = docs + components + charts + blocks + demos

    # The DOM-verified part contract for a gallery page, or nil -
    # feeds the Styling tables on component and chart pages.
    def parts_for(section, slug)
      case section
      when "components" then component_parts[slug]
      when "charts" then chart_parts[slug]
      end
    end

    private

    def component_parts
      @component_parts ||= registry_components(Poetry::Ui.root).to_h do |key, entry|
        [ key.split("/")[2..].join("-").tr("_", "-"), entry["parts"] ]
      end
    end

    def chart_parts
      @chart_parts ||= registry_components(Poetry::Charts.root).to_h do |key, entry|
        [ key.split("/").last.delete_suffix("_chart").tr("_", "-"), entry["parts"] ]
      end
    end

    def registry_keys(root)
      registry_components(root).keys
    end

    def registry_components(root)
      YAML.safe_load_file(root.join("config/component_registry.yml")).fetch("components")
    end

    def blocks_meta
      @blocks_meta ||= YAML.safe_load_file(
        Poetry::Ui.root.join("config/component_registry.yml")
      )["blocks"] || {}
    end

    def titleize(slug)
      slug.split("-").map(&:capitalize).join(" ")
    end
  end
end
