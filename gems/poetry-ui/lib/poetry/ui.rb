# frozen_string_literal: true

require "poetry/core"
require "yaml"
require_relative "ui/version"
require_relative "ui/themes"
require_relative "ui/code_block_highlighter"
require_relative "ui/recipes"
require_relative "ui/chat"

module Poetry
  # The component library: shadcn-parity ViewComponents built entirely on
  # poetry-core's PUBLIC DSL - if a component here needs private core API,
  # that is a core API gap, not a license to reach in.
  module Ui
    # The committed static-template-class list (herb-extracted in poetry's
    # CI, drift-gated) - poetry:install reads it so hosts never need herb.
    TEMPLATE_CLASSES_PATH = "config/template_classes.txt"

    # Where the block templates live: the generator's source tree,
    # scanned by the registry builder, the template-class extraction,
    # the dummy's /blocks previews, and the MCP server's describe_block.
    BLOCKS_DIR = "lib/generators/poetry/block/templates"

    # Curated composition edges: which components a copy-in of X also needs
    # locally. Single-sourced here - the add generator's recursive copy AND
    # every registry item's registryDependencies read this one map.
    # (Replaced by registry-carried anatomy when the contract's anatomy
    # section lands.)
    COMPONENT_DEPENDENCIES = {
      "button" => %w[icon],
      "dialog" => %w[button icon],
      "sheet" => %w[dialog button icon], # subclasses Dialog::Component (shared dialog controller)
      "alert_dialog" => %w[dialog button], # shares the dialog controller + posture
      "field" => %w[label input],
      "alert" => %w[icon],
      "select" => %w[icon], # chevrons + check; Field is an optional pairing, not a hard edge
      "number_field" => %w[input input_group button icon], # composes their chrome
      "stat" => %w[icon], # the delta's trend arrow
      "toolbar" => %w[button input separator], # the typed slots render them
      "file_input" => %w[input icon], # input variant wears Input; the dropzone's upload glyph
      "date_field" => %w[input], # the pre-enhancement native input wears Input's chrome
      "time_field" => %w[date_field input], # DateField at hour granularity - one segment engine
      "meter" => %w[progress], # wears Progress::Style chrome verbatim
      "search_field" => %w[input input_group button icon], # composes their chrome
      "tag_group" => %w[icon], # the remove glyph
      "timeline" => %w[icon], # the indicator glyph
      "tree" => %w[icon], # the chevron
      "clipboard_text" => %w[input input_group button icon], # composes their chrome
      "sensitive_input" => %w[input input_group button icon clipboard_text], # + the copy: engine
      "code_block" => %w[button icon] # the copy affordance
    }.freeze

    # The usage skill's family partition: every component in exactly one
    # reference file, so the skill's menu stays lean and an agent loads
    # only the family it is composing in. The coverage gate fails on any
    # new component until it is mapped here.
    SKILL_FAMILIES = {
      "forms" => %w[autocomplete button button_group calendar checkbox combobox date_field date_picker field
                    field_group field_separator fieldset
                    file_input input input_group input_otp label native_select number_field
                    questionnaire radio_group search_field select sensitive_input slider switch textarea time_field
                    toggle toggle_group],
      "overlays" => %w[alert_dialog command command_dialog context_menu dialog drawer
                       dropdown_menu hover_card menubar popover sheet tooltip],
      "data" => %w[accordion avatar badge card carousel clipboard_text code_block collapsible data_table empty
                   item metadata_list meter stat table tag_group timeline toolbar tree typeset],
      "feedback" => %w[alert deferred progress skeleton spinner toast toast_trigger toaster],
      "navigation" => %w[breadcrumb navigation_menu pagination sidebar tabs],
      "foundations" => %w[icon kbd link marker separator],
      "chat" => %w[attachment bubble message message_scroller],
      "layout" => %w[aspect_ratio resizable scroll_area]
    }.freeze

    class << self
      # Gem root (the directory containing lib/, app/, config/).
      def root
        @root ||= Pathname.new(File.expand_path("../..", __dir__))
      end

      # @return [Array<String>] the committed template-static classes
      def template_classes
        root.join(TEMPLATE_CLASSES_PATH).read.lines
            .map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
      end

      # The public poetry_* helper names, so poetry check / poetry-agent know
      # the full set (group / provider helpers AND the define_method'd part
      # helpers like poetry_table_cell) WITHOUT booting Rails. The module's
      # method bodies reference component constants only at call time, so
      # requiring the file standalone is safe.
      def helper_names
        require root.join("app/helpers/poetry/ui/components_helper.rb")
        ComponentsHelper.public_instance_methods(false).grep(/\Apoetry_/).map(&:to_s)
      rescue StandardError
        # Fallback: the static-def helpers (misses define_method ones) if the
        # module can't load standalone in some host.
        root.join("app/helpers/poetry/ui/components_helper.rb").read.scan(/def (poetry_[a-z_]+)/).flatten.uniq
      end

      # The registry builder this gem commits from (booted contexts only:
      # rake registry:generate/verify and the sync test share it, so the
      # drift gate always compares against the exact construction that
      # generated the file - helpers AND blocks sections included).
      def registry
        components = Poetry::Core::Registry.new(source_root: root).components
        component_paths = components.map(&:component_path)
        Poetry::Core::Registry.new(
          components: components, source_root: root,
          helpers: registry_helpers(component_paths: component_paths),
          blocks: registry_blocks(component_paths: component_paths),
          helper_args: registry_helper_args,
          descriptions: registry_descriptions,
          form_builder: Poetry::Ui::FormBuilder.registry_section
        )
      end

      # The editorial per-component descriptions merged into the registry
      # (component_path => one-liner, from config/component_descriptions.yml).
      # Absent file -> nil, so a registry without it stays lint-identical, like
      # every other optional section.
      def registry_descriptions
        path = root.join("config/component_descriptions.yml")
        path.exist? ? YAML.safe_load_file(path) : nil
      end

      # The shadcn-interop item projection, boot-free
      # from the COMMITTED registry - the docs site serves /r/*.json from
      # this, and the add generator matches gem-satisfied dependencies
      # against its names.
      def registry_items
        Poetry::Core::RegistryItems.new(
          registry: YAML.safe_load_file(root.join(Poetry::Core::Registry::RELATIVE_PATH)),
          root: root, gem_name: "poetry-ui", gem_version: VERSION,
          dependencies: COMPONENT_DEPENDENCIES
        )
      end

      # The recipes projection: skill bundles, scaffold template
      # sets, and screen slices as registry items -
      # served at /r/*.json beside components and blocks, installed by
      # poetry:add or any shadcn-compatible client.
      def recipe_items
        Poetry::Core::RecipeItems.new(
          recipes: Recipes.definitions, gem_name: "poetry-ui", gem_version: VERSION
        )
      end

      # The installable component-usage skill: a lean SKILL.md menu +
      # per-family references, generated from the live
      # registry - the seam the poetry:skill generator and the eval
      # harness share (the agents_section_text pattern).
      def skill_files
        Poetry::Core::SkillText.new(
          registry: registry, families: SKILL_FAMILIES, charts_registry: charts_registry
        ).files
      end

      # Tolerant on charts, like the AGENTS.md census: a host without the
      # gem (or with a stubbed/partial one) just drops the charts reference.
      def charts_registry
        return nil unless defined?(Poetry::Charts::Engine)

        Poetry::Charts.registry
      rescue StandardError
        nil
      end

      # The MCP server's runtime skill map (get_skill): the SAME
      # files `rails g poetry:skill` writes, for hosts that cannot write
      # files. Boot-free by construction - the usage skill regenerates from
      # the COMMITTED registries (never the booted builders above), the
      # design skill reads its static templates - so the exe can serve both
      # without Rails. Lazy: nothing generates until an agent asks.
      def agent_skills
        {
          "poetry" => -> { runtime_skill_files },
          "poetry-design" => lambda {
            require "generators/poetry/skills_section"
            Object.new.extend(Poetry::Generators::SkillsSection).design_skill_files
          },
          "poetry-component" => lambda {
            require "generators/poetry/skills_section"
            Object.new.extend(Poetry::Generators::SkillsSection).component_skill_files
          }
        }
      end

      def runtime_skill_files
        Poetry::Core::SkillText.new(
          registry: Poetry::Core::Registry.committed(root),
          families: SKILL_FAMILIES, charts_registry: committed_charts_registry
        ).files
      end

      # The charts reference rides along whenever the charts gem is present
      # (its committed registry, not its booted builder); absent, the skill
      # simply drops it - the charts_registry tolerance, boot-free.
      def committed_charts_registry
        require "poetry/charts"
        Poetry::Core::Registry.committed(Poetry::Charts.root)
      rescue LoadError, StandardError
        nil
      end

      # The registry "helper_args" map: max positional arity for EVERY
      # poetry_* helper, introspected from the real method signatures (the
      # site_nav crash: `poetry_link "text", href:` on a
      # kwargs-only helper). Rest-signatures are omitted - the linter
      # enforces arity only where a key exists.
      POSITIONAL_PARAM_KINDS = %i[req opt].freeze

      def registry_helper_args
        helper_names.sort.filter_map do |name|
          params = ComponentsHelper.instance_method(name.to_sym).parameters
          next if params.any? { |kind, _param| kind == :rest }

          [name, params.count { |kind, _param| POSITIONAL_PARAM_KINDS.include?(kind) }]
        end.to_h
      end

      # The registry "helpers" section: every poetry_* helper that
      # maps to no component - group/provider/item wrappers - each carrying
      # its declared value contract (ComponentsHelper::HELPER_CONTRACTS) or
      # {} for a plain wrapper.
      def registry_helpers(component_paths:)
        mapped = component_paths.map { |path| "poetry_#{path.delete_prefix("poetry/ui/").tr("/", "_")}" }
        (helper_names - mapped).sort.to_h do |name|
          [name, ComponentsHelper::HELPER_CONTRACTS.fetch(name, {})]
        end
      end

      # The registry "blocks" section: every block template's metadata,
      # all source-derived - title/description/keywords from the
      # mandatory poetry:block header (keywords power the MCP compose
      # tool's brief routing), the composed component list from the
      # template's own poetry_* calls (longest-prefix fold:
      # sidebar_menu_button counts as sidebar), the gem-relative template
      # path for boot-free source reads. No hand-authored catalog to drift.
      def registry_blocks(component_paths:)
        titles = component_paths.map { |path| path.delete_prefix("poetry/ui/").tr("/", "_") }
        Dir.glob(root.join(BLOCKS_DIR, "*.html.erb").to_s).to_h do |file|
          source = File.read(file)
          header = source.match(
            /\A<%#\s*poetry:block\s+title="([^"]*)"\s+description="([^"]*)"(?:\s+keywords="([^"]*)")?\s*%>/
          )
          raise Poetry::Core::Error, "#{file} is missing its poetry:block header" unless header

          entry = { "title" => header[1], "description" => header[2],
                    "components" => block_components(source, titles: titles),
                    "template" => "#{BLOCKS_DIR}/#{File.basename(file)}" }
          entry["keywords"] = header[3].split(",").map(&:strip) if header[3]
          [File.basename(file, ".html.erb").tr("_", "-"), entry]
        end
      end

      # The distinct components a block composes, folded from its poetry_*
      # helper calls: each call maps to the LONGEST component title that
      # prefixes it (poetry_sidebar_menu_badge -> sidebar; poetry_table_head
      # -> table); calls matching no component (pure wrapper helpers like
      # poetry_input_group_addon fold through input_group) are dropped
      # rather than guessed.
      def block_components(source, titles:)
        source.scan(/\bpoetry_([a-z0-9_]+)/).flatten.uniq.filter_map do |called|
          titles.select { |title| called == title || called.start_with?("#{title}_") }.max_by(&:length)
        end.uniq.sort
      end
    end
  end
end

require_relative "ui/engine"
