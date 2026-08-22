# frozen_string_literal: true

# The operator register ('s banked lead, built as the docs-site
# self-embed): poetry's component contract projected in OPERATOR
# vocabulary - what an in-page GUI agent needs to USE the rendered
# components, as opposed to the author register (llms.txt) for agents
# writing ERB. Served at /operator-register.json and fed to the embedded
# page-agent via instructions.system + getPageInstructions; the page
# inventory derives from DocsCatalog, so a new page appears here the
# moment the registry ships it. FAMILY_VERBS is the one authored table
# (operator prose cannot be derived); components without an entry get the
# generic line, so the register can lag the roster but never lie about it.
class OperatorRegister
  SYSTEM = <<~TEXT.strip
    This site is built from poetry components. Every component stamps
    data-component (its family) and data-slot (its parts) - trust those over
    guessing from classes. Ground rules: interactive components follow WAI-ARIA
    patterns - triggers carry aria-expanded/aria-haspopup, open surfaces are
    dialogs/listboxes/menus portaled to the end of <body>, and one open surface
    at a time (opening another dismisses the first, clicking outside dismisses).
    Never click through an overlay scrim - dismiss first (Escape or outside
    click). Form controls have real labels; prefer clicking labels/options over
    coordinates. Tabs on this site: each example frame is its own tab group -
    use the group nearest your target. The command palette opens with the
    search button in the header. Some components are keyboard-first (sliders,
    date/time segments, OTP inputs) and may not respond to clicks alone.
  TEXT

  GENERIC_VERB = "static content - read it; no interaction contract beyond links"

  # Operator lines for the interactive families, keyed by kebab component
  # name (the data-component value). Authored once; reviewed when a family's
  # interaction contract changes.
  FAMILY_VERBS = {
    "accordion" => "click a section header to expand/collapse it",
    "alert-dialog" => "opens on its trigger; confirm or cancel with the buttons - Escape cancels",
    "button" => "click it; disabled buttons ignore clicks",
    "calendar" => "click a day to select; arrow buttons change the month",
    "checkbox" => "click the box or its label to toggle",
    "collapsible" => "click the trigger to show/hide the content",
    "combobox" => "click the trigger, type to filter, click an option; multiple-mode keeps it open",
    "command" => "type to filter the list, click an item to run it; Escape closes the palette",
    "context-menu" => "right-click the surface to open; click an item",
    "data-table" => "click column headers to sort; row checkboxes select; the action bar appears on selection",
    "date-field" => "keyboard-first: click a segment, then TYPE the value (typed input works; clicking alone never sets it - measured: typing succeeds where 26 clicks failed)",
    "dialog" => "opens on its trigger; the X button or Escape closes; clicking the scrim closes",
    "drawer" => "opens on its trigger from the edge; Escape or the scrim closes",
    "dropdown-menu" => "click the trigger, click an item (items may be links); Escape closes",
    "field" => "a labeled control group - operate the control inside it",
    "hover-card" => "hover the trigger to reveal; do not click to open",
    "input" => "click then type; masked inputs format as you type",
    "input-group" => "operate the input inside; addons are decorative or buttons",
    "input-otp" => "keyboard-first: click the first cell then type the code digits",
    "menubar" => "click a menu name, then click an item; arrow keys move across menus",
    "navigation-menu" => "click a top item to open its panel; links navigate",
    "number-field" => "type a number, or click the +/- steppers",
    "pagination" => "click a page number or prev/next link to navigate",
    "popover" => "click the trigger to open; Escape or outside click closes",
    "radio-group" => "click one option or its label; selection is exclusive",
    "select" => "click the trigger, then click an option in the popup listbox; Escape closes",
    "sidebar" => "the rail toggle collapses/expands it; menu entries are links",
    "slider" => "keyboard-first: arrow-key the focused thumb; track clicks move it COARSELY but cannot hit exact values (measured: 39 clicks never landed max)",
    "switch" => "click it or its label to toggle",
    "table" => "read it; if selectable, row checkboxes select",
    "tabs" => "click a tab to switch panels - scope to the NEAREST tab group",
    "tag-group" => "click a tag's remove button to delete it",
    "time-field" => "keyboard-first: click a segment, then TYPE the value (typed input works; clicking alone never sets it)",
    "toggle" => "click to press/unpress",
    "toggle-group" => "click one (or more, if multiple) of the pressed-state buttons",
    "tooltip" => "hover to reveal; never required for operation",
    "tree" => "click a row's caret to expand; click a row to select"
  }.freeze

  class << self
    # { "system" => ..., "pages" => { "/components/select" => "...", ... },
    #   "default" => site-chrome line } - consumed by the demo's
    #   getPageInstructions (longest-prefix lookup client-side).
    def as_json
      { "system" => SYSTEM, "default" => default_line, "pages" => pages }
    end

    def pages
      @pages ||= DocsCatalog.all.to_h { |entry| [ entry.path, page_line(entry) ] }
    end

    def page_line(entry)
      case entry.section
      when "components" then component_line(entry)
      when "charts"
        "This page documents the #{entry.title} (data-component=#{entry.slug.tr('-', '_')}_chart): " \
          "server-rendered SVG - hover for tooltips; interactive demos are separate pages. #{examples_line}"
      when "blocks"
        components = DocsCatalog.block_meta(entry.slug)&.fetch("components", []) || []
        "This page previews the #{entry.title} block, composing: #{components.join(', ')}. " \
          "Operate the preview like a real screen."
      when "demos" then "#{entry.title} demo: #{entry.description}"
      else
        "#{entry.title} guide. #{examples_line}"
      end
    end

    def component_line(entry)
      verbs = FAMILY_VERBS.fetch(entry.slug, GENERIC_VERB)
      "This page documents #{entry.title} (data-component=#{data_component(entry.slug)}): #{verbs}. #{examples_line}"
    end

    # The ACTUAL data-component value: underscores survive in the DOM
    # (date_field, navigation_menu) and only path nesting joins with a
    # dash (command/dialog -> command-dialog). DocsCatalog slugs kebab
    # BOTH, so derive from the registry key - the findings pass caught the
    # register claiming values the DOM never stamps.
    def data_component(slug)
      component_values.fetch(slug, slug)
    end

    def component_values
      @component_values ||= YAML.safe_load_file(
        Poetry::Ui.root.join("config/component_registry.yml")
      )["components"].keys.to_h do |key|
        parts = key.split("/")[2..]
        [ parts.join("-").tr("_", "-"), parts.join("-") ]
      end
    end

    def examples_line
      "Each example sits in a Preview/Code tab pair - operate inside the Preview tab of the example you need."
    end

    def default_line
      "poetry docs chrome: sidebar navigation on the left, search/command palette " \
        "in the header, theme and style switchers top right."
    end
  end
end
