# frozen_string_literal: true

require "rails/generators"
require "yaml"

module Poetry
  # `rails g poetry:add Button [Dialog...]` - the copy-in tier:
  # copies a component's source (component.rb, style.rb, template, preview)
  # into the host's app/components, where Rails autoload precedence shadows
  # the gem copy - "own the code". Dependencies resolve recursively;
  # existing files are SKIPPED, never clobbered (local edits win, always).
  # Installed components are recorded in config/poetry_components.yml with
  # the gem version they came from (the upgrade story's provenance).
  class AddGenerator < Rails::Generators::Base
    argument :component_names, type: :array, banner: "Component Component ..."

    # Composition edges (replaced by registry-carried anatomy when the
    # contract's anatomy section lands - see the Component Plan Contract).
    DEPENDENCIES = {
      "button" => %w[icon],
      "dialog" => %w[button icon],
      "field" => %w[label input],
      "alert" => %w[icon]
    }.freeze

    MANIFEST = "config/poetry_components.yml"

    desc "Copy poetry components (plus their dependencies) into the app - local copies shadow the gem"

    def add_components
      resolved = resolve(component_names.map(&:underscore))
      missing = resolved.reject { |name| source_dir(name).directory? }
      raise ArgumentError, "unknown component(s): #{missing.join(", ")}" if missing.any?

      resolved.each { |name| copy_component(name) }
      record_in_manifest(resolved)
    end

    private

    def resolve(names, seen = [])
      names.each do |name|
        next if seen.include?(name)

        seen << name
        resolve(DEPENDENCIES.fetch(name, []), seen)
      end
      seen
    end

    def source_dir(name)
      Poetry::Ui.root.join("app/components/poetry/ui", name)
    end

    def copy_component(name)
      source_dir(name).glob("*").each do |file|
        # skip-if-exists: a customized local copy is never overwritten.
        create_file "app/components/poetry/ui/#{name}/#{file.basename}", file.read, skip: true
      end
    end

    def record_in_manifest(names)
      path = File.join(destination_root, MANIFEST)
      manifest = File.exist?(path) ? YAML.safe_load_file(path) : nil
      manifest = { "components" => {} } unless manifest.is_a?(Hash) && manifest["components"].is_a?(Hash)
      names.each do |name|
        manifest["components"][name] ||= { "version" => Poetry::Ui::VERSION }
      end
      create_file MANIFEST, YAML.dump(manifest), force: true
    end
  end
end
