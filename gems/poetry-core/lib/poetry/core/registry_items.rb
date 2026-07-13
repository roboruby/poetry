# frozen_string_literal: true

require "yaml"

module Poetry
  module Core
    # The shadcn-interop projection of a gem's registry (Ecosystem v1,
    #): every component and block as a registry-item hash matching the
    # shadcn registry-item.json schema - name / type / title / files[]
    # ({path, content, type, target}) / registryDependencies / meta - plus
    # index summaries for registry.json. Built BOOT-FREE from the committed
    # component_registry.yml + the source tree, so the docs site serves
    # GET /r/:name.json live and any shadcn-compatible tool can consume a
    # poetry item. Names are kebab-case with the gem prefix stripped
    # (poetry/ui/command/dialog -> command-dialog), matching the block
    # catalog's existing naming.
    class RegistryItems
      ITEM_SCHEMA = "https://ui.shadcn.com/schema/registry-item.json"

      # The same header strip the block generator applies: the poetry:block
      # comment is registry metadata, not file content.
      BLOCK_HEADER = /\A<%#\s*poetry:block[^%]*%>\n?/

      # @param registry [Hash] a parsed component_registry.yml payload
      # @param root [Pathname, String] the gem root files resolve against
      # @param gem_name [String] recorded in every item's meta
      # @param gem_version [String] recorded in every item's meta
      # @param dependencies [Hash] curated composition edges (underscore
      #   component name => [underscore names]) - the add generator's map,
      #   single-sourced by the owning gem
      def initialize(registry:, root:, gem_name:, gem_version:, dependencies: {})
        @registry = registry
        @root = Pathname.new(root)
        @gem_name = gem_name
        @gem_version = gem_version
        @dependencies = dependencies
      end

      # Every item name (components + blocks), collision-checked: one flat
      # kebab namespace per gem, like shadcn's.
      def names
        @names ||= begin
          all = component_paths.keys + blocks.keys
          duplicates = all.tally.select { |_name, count| count > 1 }.keys
          raise Error, "registry item name collision: #{duplicates.join(", ")}" if duplicates.any?

          all.sort
        end
      end

      def item(name)
        if (path = component_paths[name])
          component_item(name, path)
        elsif (entry = blocks[name])
          block_item(name, entry)
        end
      end

      # Index entries: the full item minus file content (shadcn's
      # registry.json shape - paths and targets stay, bytes don't).
      def summaries
        names.map do |name|
          full = item(name)
          full.merge("files" => full["files"].map { |file| file.except("content") })
        end
      end

      private

      def components
        @registry["components"] || {}
      end

      def blocks
        @registry["blocks"] || {}
      end

      def component_paths
        @component_paths ||= components.keys.to_h do |path|
          [path.delete_prefix(path_prefix).tr("/", "_").tr("_", "-"), path]
        end
      end

      # The gem prefix to strip is the component paths' common DIRECTORY
      # prefix (poetry/ui/button + poetry/ui/command/dialog -> poetry/ui/):
      # derived, so every gem's items flatten the same way with nothing to
      # configure.
      def path_prefix
        @path_prefix ||= begin
          dirs = components.keys.map { |path| path.split("/")[0..-2] }
          common = dirs.reduce { |left, right| left.zip(right).take_while { |a, b| a == b }.map(&:first) }
          common.nil? || common.empty? ? "" : "#{common.join("/")}/"
        end
      end

      def component_item(name, path)
        entry = components.fetch(path)
        {
          "$schema" => ITEM_SCHEMA,
          "name" => name,
          "type" => "registry:component",
          "title" => name.tr("-", " ").capitalize,
          "files" => component_files(path),
          "registryDependencies" => (@dependencies[name.tr("-", "_")] || []).map { |dep| dep.tr("_", "-") },
          "meta" => component_meta(entry)
        }
      end

      # The part contract rides meta so /r consumers see the
      # DOM-verified styling surface without fetching the source.
      def component_meta(entry)
        meta = { "gem" => @gem_name, "gem_version" => @gem_version, "provided" => "runtime-gem",
                 "class_name" => entry["class_name"], "identifier" => entry["identifier"] }
        meta["parts"] = entry["parts"] if entry["parts"]
        meta
      end

      # The component's whole source dir (component.rb, style.rb, template,
      # preview) - the same set the copy-in generator installs, target
      # mirroring path. Files belonging to a NESTED registered component
      # stay with their own item, in both nesting shapes: a subdirectory,
      # or the sibling-file convention (command/dialog keeps
      # dialog_component.rb beside its parent).
      def component_files(path)
        dir = @root.join("app/components", path)
        return sibling_files(path) unless dir.directory?

        dir.glob("**/*").select(&:file?).sort.filter_map do |file|
          rel = "app/components/#{path}/#{file.relative_path_from(dir)}"
          next if nested_dir_prefixes(path).any? { |prefix| rel.start_with?("app/components/#{prefix}") }
          next if nested_leaves(path).any? { |leaf| file.basename.to_s.start_with?("#{leaf}_") }

          { "path" => rel, "content" => file.read, "type" => "registry:file", "target" => rel }
        end
      end

      def nested_dir_prefixes(path)
        components.keys.filter_map { |other| "#{other}/" if other.start_with?("#{path}/") }
      end

      def nested_leaves(path)
        components.keys.filter_map do |other|
          next unless other.start_with?("#{path}/")

          File.basename(other) unless @root.join("app/components", other).directory?
        end
      end

      # A nested component with no directory of its own keeps its files
      # beside its parent, prefixed with its leaf name (dialog_component.rb,
      # dialog_component.html.erb, dialog_preview.rb).
      def sibling_files(path)
        parent = File.dirname(path)
        leaf = File.basename(path)
        @root.join("app/components", parent).glob("#{leaf}_*").select(&:file?).sort.map do |file|
          rel = "app/components/#{parent}/#{file.basename}"
          { "path" => rel, "content" => file.read, "type" => "registry:file", "target" => rel }
        end
      end

      def block_item(name, entry)
        source = @root.join(entry.fetch("template")).read
        target = "app/views/blocks/_#{name.tr("-", "_")}.html.erb"
        {
          "$schema" => ITEM_SCHEMA,
          "name" => name,
          "type" => "registry:block",
          "title" => entry["title"],
          "description" => entry["description"],
          "files" => [{ "path" => entry.fetch("template"), "content" => source.sub(BLOCK_HEADER, ""),
                        "type" => "registry:file", "target" => target }],
          "registryDependencies" => (entry["components"] || []).map { |dep| dep.tr("_", "-") },
          "meta" => { "gem" => @gem_name, "gem_version" => @gem_version, "provided" => "copy-in",
                      "keywords" => entry["keywords"] }.compact
        }
      end
    end
  end
end
