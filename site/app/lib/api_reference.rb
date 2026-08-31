# frozen_string_literal: true

# The /api section's data source: the committed data/api/*.json exports of
# each gem's YARD registry (regenerate with `bin/rails docs:api_reference`).
# Everything here reads the JSON snapshot - the docs app never loads the
# satellite gems themselves, so /api can document gems the site doesn't run.
class ApiReference
  GEMS = {
    "poetry-core" => {
      "title" => "poetry-core",
      "description" => "The engine: the Component base class, the option / style / part / " \
                       "use_stimulus DSLs, the style dictionary, tokens, icons, and the registry.",
      "pins" => %w[Poetry::Core::Component Poetry::Core::Concerns::Options
                   Poetry::Core::Concerns::Styles Poetry::Core::Concerns::Parts
                   Poetry::Core::Concerns::Stimulus Poetry::Core::Style
                   Poetry::Core::Stimulus::Declarations Poetry::Core::Tokens
                   Poetry::Core::Icons Poetry::Core::Registry]
    },
    "poetry-controllers" => {
      "title" => "@poetry/controllers",
      "description" => "The JavaScript surface: the 53 Stimulus controllers and the DOM " \
                       "helper modules, one source over two channels (the engine's importmap " \
                       "pins and the npm package) - generated from the source JSDoc and the " \
                       "controllers manifest.",
      "note" => "Generated from the source JSDoc plus the introspected controllers " \
                "manifest. What each component wires is on its gallery page - this page " \
                "documents the JS surface itself: identifiers, values, events, actions, " \
                "and the helper modules.",
      "pins" => %w[@poetry/controllers poetry--core--state poetry--core--dialog
                   poetry--core--popper poetry--core--dismissable poetry--core--focus-scope
                   poetry--core--roving-focus @poetry/controllers/helpers/state
                   @poetry/controllers/helpers/presence @poetry/controllers/helpers/portal]
    },
    "poetry-ui" => {
      "title" => "poetry-ui",
      "description" => "The component suite's Ruby surface beyond the gallery: the poetry_* " \
                       "view helpers, the model-bound FormBuilder, the Testing helpers, and " \
                       "the chat replay DSL.",
      "pins" => %w[Poetry::Ui::ComponentsHelper Poetry::Ui::FormBuilder
                   Poetry::Ui::Testing Poetry::Ui::Chat],
      # Component classes render on their own gallery pages (the API
      # section there) - the gem page carries everything else.
      "skip" => /\A(Poetry::Ui::[A-Z]\w*::|Poetry::Ui::Menus\b|Poetry::Ui::FamilyIdentity\b|Poetry::Ui::PopperConsumer\b|Poetry::Ui::InputGroupField\b|Poetry::Ui::ComposableTrigger\b)/
    },
    "poetry-charts" => {
      "title" => "poetry-charts",
      "description" => "The charts gem's Ruby surface: the chart helpers, the shared chart " \
                       "chassis, and the geometry layer (scales, curves, ticks, paths).",
      "pins" => %w[Poetry::Charts::ComponentsHelper Poetry::Charts::Config Poetry::Charts::Spec],
      "skip" => /\A(Poetry::Charts::[A-Z]\w*Chart::|Poetry::Charts::Container::|Poetry::Charts::LegendContent::|Poetry::Charts::TooltipContent::|Poetry::Charts::TooltipLayer::)/
    },
    "poetry-charts-controllers" => {
      "title" => "@poetry/charts",
      "description" => "The charts JavaScript surface: the five Stimulus chrome controllers " \
                       "(tooltip, motion, live, window, adapter), the BYO-engine adapter " \
                       "seam, and the motion/live modules - generated from the source JSDoc " \
                       "and the controllers manifest.",
      "note" => "Generated from the source JSDoc plus the introspected controllers " \
                "manifest. Chart anatomy and the Ruby surface live on the chart pages and " \
                "the poetry-charts API page - this page documents the JS itself.",
      "pins" => %w[@poetry/charts poetry--charts--tooltip poetry--charts--live
                   poetry--charts--motion poetry--charts--window poetry--charts--adapter
                   @poetry/charts/adapter_registry @poetry/charts/motion/flip]
    },
    "poetry-agent" => {
      "title" => "poetry-agent",
      "description" => "The agent-interop gem: the MCP server (stdio exe and the Rack HTTP " \
                       "transport), its bundled assembly, the WebMCP runtime's Ruby side, and " \
                       "the origin-trial middleware.",
      "pins" => %w[Poetry::Agent Poetry::Agent::MCP::Server Poetry::Agent::MCP::HTTP
                   Poetry::Agent::MCP::Bundled Poetry::Agent::WebMCP
                   Poetry::Agent::WebMCP::OriginTrial Poetry::Agent::Config]
    },
    "poetry-simple_form" => {
      "title" => "poetry-simple_form",
      "description" => "The simple_form adapter: activate! plus the input classes that map " \
                       "simple_form types onto poetry fields.",
      "pins" => %w[Poetry::SimpleForm]
    },
    "poetry-extract" => {
      "title" => "poetry-extract",
      "description" => "Domain-to-theme extraction: fetch a site's design signals and " \
                       "compose a DESIGN.md + token set from them.",
      "pins" => %w[Poetry::Extract::Runner]
    }
  }.freeze

  class << self
    # The gem slugs with a committed export, in GEMS order.
    def slugs = GEMS.keys.select { |slug| path_for(slug).exist? }

    def meta(slug) = GEMS[slug]

    # The gem-page object list: pinned first, the rest alphabetical,
    # component-family classes (rendered on gallery pages) skipped.
    def page_objects(slug)
      meta = GEMS.fetch(slug)
      objects = objects(slug)
      objects = objects.reject { |o| o["path"] =~ meta["skip"] } if meta["skip"]
      pins = meta["pins"] || []
      objects.sort_by { |o| [ pins.index(o["path"]) || pins.length, o["path"] ] }
    end

    # One class's export entry (for the gallery pages' API section).
    def object(slug, path)
      objects(slug).find { |o| o["path"] == path }
    end

    def objects(slug)
      (@objects ||= {})[slug] ||= JSON.parse(path_for(slug).read).fetch("objects")
    end

    def reset! = @objects = nil

    private

    def path_for(slug) = Rails.root.join("data/api/#{slug}.json")
  end
end
