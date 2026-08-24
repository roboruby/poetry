# frozen_string_literal: true

module Poetry
  module Core
    # The recipes projection: multi-file, non-UI payloads
    # - skill bundles, scaffold template sets, screen slices - served
    # through the same registry-item schema as components and
    # blocks. Like RegistryItems, this is a LIVE projection: a recipe
    # declares its files as callables over gem-shipped sources, so the
    # served item can never drift from what the generators install.
    #
    # @api private
    class RecipeItems
      # The published registry-item JSON schema recipes are served under -
      # the same schema component items validate against.
      ITEM_SCHEMA = RegistryItems::ITEM_SCHEMA

      # @param recipes [Array<Hash>] declarations: "name" (flat kebab),
      #   "title", "description", optional "registry_dependencies"
      #   (kebab item names), and "files" - a callable (or array)
      #   yielding { "path" =>, "target" =>, "content" => } hashes.
      #   Targets must be relative and traversal-free; enforced here so a
      #   bad declaration fails in the gem's suite, not in a host.
      # @param gem_name [String] recorded in every item's meta
      # @param gem_version [String] recorded in every item's meta
      def initialize(recipes:, gem_name:, gem_version:)
        @list = recipes
        @gem_name = gem_name
        @gem_version = gem_version
      end

      def names
        @names ||= begin
          all = @list.map { |recipe| recipe.fetch("name") }
          duplicates = all.tally.select { |_name, count| count > 1 }.keys
          raise Error, "recipe name collision: #{duplicates.join(", ")}" if duplicates.any?

          all.sort
        end
      end

      def item(name)
        recipe = @list.find { |candidate| candidate.fetch("name") == name }
        return nil unless recipe

        {
          "$schema" => ITEM_SCHEMA,
          "name" => name,
          "type" => "registry:block",
          "title" => recipe.fetch("title"),
          "description" => recipe.fetch("description"),
          "files" => recipe_files(recipe),
          "registryDependencies" => recipe["registry_dependencies"] || [],
          "meta" => { "gem" => @gem_name, "gem_version" => @gem_version,
                      "provided" => "copy-in", "kind" => "recipe" }
        }
      end

      def summaries
        names.map do |name|
          full = item(name)
          full.merge("files" => full["files"].map { |file| file.except("content") })
        end
      end

      private

      def recipe_files(recipe)
        source = recipe.fetch("files")
        (source.respond_to?(:call) ? source.call : source).map do |file|
          target = file.fetch("target")
          unless Pathname.new(target).relative? && target.split("/").none?("..")
            raise Error, "recipe #{recipe.fetch("name")} has an unsafe target: #{target}"
          end

          { "path" => file.fetch("path"), "content" => file.fetch("content"),
            "type" => "registry:file", "target" => target }
        end
      end
    end
  end
end
