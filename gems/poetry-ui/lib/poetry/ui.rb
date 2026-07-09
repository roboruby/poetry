# frozen_string_literal: true

require "poetry/core"
require_relative "ui/version"
require_relative "ui/themes"

module Poetry
  # The component library: shadcn-parity ViewComponents built entirely on
  # poetry-core's PUBLIC DSL - if a component here needs private core API,
  # that is a core API gap, not a license to reach in (dogfooding).
  module Ui
    # The committed static-template-class list (herb-extracted in poetry's
    # CI, drift-gated) - poetry:install reads it so hosts never need herb.
    TEMPLATE_CLASSES_PATH = "config/template_classes.txt"

    # Where the block templates live (Blocks v1): the generator's source
    # tree, scanned by the registry builder, the template-class extraction,
    # the dummy's /blocks previews, and the MCP server's describe_block.
    BLOCKS_DIR = "lib/generators/poetry/block/templates"

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
          helper_args: registry_helper_args
        )
      end

      # The registry "helper_args" map: max positional arity for EVERY
      # poetry_* helper, introspected from the real method signatures (the
      # blocks-gate site_nav crash: `poetry_link "text", href:` on a
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

      # The registry "blocks" section (Blocks v1): every block template's
      # metadata, all source-derived - title/description from the mandatory
      # poetry:block header, the composed component list from the template's
      # own poetry_* calls (longest-prefix fold: sidebar_menu_button counts
      # as sidebar), the gem-relative template path for boot-free source
      # reads. No hand-authored catalog to drift.
      def registry_blocks(component_paths:)
        titles = component_paths.map { |path| path.delete_prefix("poetry/ui/").tr("/", "_") }
        Dir.glob(root.join(BLOCKS_DIR, "*.html.erb").to_s).to_h do |file|
          source = File.read(file)
          header = source.match(/\A<%#\s*poetry:block\s+title="([^"]*)"\s+description="([^"]*)"\s*%>/)
          raise Poetry::Core::Error, "#{file} is missing its poetry:block header" unless header

          [File.basename(file, ".html.erb").tr("_", "-"),
           { "title" => header[1], "description" => header[2],
             "components" => block_components(source, titles: titles),
             "template" => "#{BLOCKS_DIR}/#{File.basename(file)}" }]
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
