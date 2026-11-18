# frozen_string_literal: true

require "json"

# The Claude Code plugin the repository publishes: a marketplace manifest
# at the repository root and one plugin folder under plugins/, holding the
# same skills `bin/rails g poetry:skill` installs in an app and the site
# serves under /.well-known/skills. A plugin reaches a session that has no
# Rails app in front of it yet, which the other two cannot.
#
# Every file is a projection of SkillCatalog and the gem's own metadata,
# so the plugin cannot say something the installed skills do not: `rake
# poetry_docs:plugin` writes the files, and a test fails when the
# committed ones differ.
#
# @example What the repository should hold, path => content
#   PluginBundle.files.keys.first(2)
#   # => [".claude-plugin/marketplace.json", "plugins/poetry/.claude-plugin/plugin.json"]
module Poetry
  module Docs
    class PluginBundle
      # The marketplace's name, which `claude plugin install poetry@poetry` ends in.
      MARKETPLACE = "poetry"
      # The plugin's name; its skills run as /poetry:<skill>.
      PLUGIN = "poetry"
      # The plugin's folder, from the repository root.
      SOURCE = "plugins/poetry"
      # The marketplace manifest's path, where Claude Code looks for it.
      MANIFEST = ".claude-plugin/marketplace.json"
      DESCRIPTION = "Skills for building Rails interfaces with Poetry, a ViewComponent and Stimulus component " \
                    "library: using the components, composing a page, authoring a component, and reading the " \
                    "documentation site."

      # The repository root: the engine lives at gems/poetry-docs.
      def self.root
        Poetry::Docs.root.join("../..").expand_path
      end

      # Every file the plugin is made of, repository-relative path => content.
      def self.files
        skills = SkillCatalog.sets.flat_map do |name, set|
          set.map { |relative, content| [ "#{SOURCE}/skills/#{name}/#{relative}", content ] }
        end
        { MANIFEST => json(marketplace), "#{SOURCE}/.claude-plugin/plugin.json" => json(plugin) }.merge(skills.to_h)
      end

      # Writes the files under a root and removes whatever else the plugin
      # folder holds, so a renamed skill file does not linger.
      def self.write(root = self.root)
        expected = files
        expected.each do |relative, content|
          path = Pathname(root).join(relative)
          path.dirname.mkpath
          path.write(content)
        end
        extra(root, expected).each { |relative| Pathname(root).join(relative).delete }
        expected.size
      end

      # The paths under a root that are missing, differ, or should not be there.
      def self.stale(root = self.root)
        expected = files
        differing = expected.reject do |relative, content|
          path = Pathname(root).join(relative)
          path.file? && path.read == content
        end
        differing.keys + extra(root, expected)
      end

      def self.marketplace
        {
          name: MARKETPLACE,
          description: "The Poetry component library for Rails, for Claude Code.",
          owner: { name: spec.authors.first, url: spec.homepage },
          plugins: [ { name: PLUGIN, source: "./#{SOURCE}", description: DESCRIPTION } ]
        }
      end

      def self.plugin
        {
          name: PLUGIN,
          description: DESCRIPTION,
          version: Poetry::Ui::VERSION,
          author: { name: spec.authors.first },
          homepage: spec.homepage,
          repository: "https://github.com/roboruby/poetry",
          license: spec.license,
          keywords: %w[rails viewcomponent stimulus hotwire components ui]
        }
      end

      # The gem whose metadata the manifests repeat (author, homepage, license).
      def self.spec
        Gem.loaded_specs.fetch("poetry-ui")
      end

      def self.json(data)
        "#{JSON.pretty_generate(data)}\n"
      end

      # Files in the plugin folder that the plugin no longer has.
      def self.extra(root, expected)
        folder = Pathname(root).join(SOURCE)
        return [] unless folder.directory?

        present = folder.glob("**/*", File::FNM_DOTMATCH).select(&:file?).map { |path| path.relative_path_from(root).to_s }
        present - expected.keys
      end

      private_class_method :marketplace, :plugin, :spec, :json, :extra
    end
  end
end
