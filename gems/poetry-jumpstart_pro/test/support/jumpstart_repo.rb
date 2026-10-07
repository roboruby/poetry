# frozen_string_literal: true

# Locates a real, PRIVATE Jumpstart Pro checkout for the drift-guard tests.
# The repo is never copied into or committed to this project - it is read
# in place, by path, from JUMPSTART_PRO_PATH. Tests skip when it is absent.
module JumpstartRepo
  ENGINE_VIEWS = "lib/jumpstart/app/views"

  def self.path
    raw = ENV["JUMPSTART_PRO_PATH"].to_s
    return nil if raw.empty?

    dir = File.expand_path(raw)
    File.directory?(File.join(dir, "lib/jumpstart")) ? dir : nil
  end

  # The engine view that a given host override (relative to app/views) shadows.
  def self.original_for(view_relative_path)
    root = path or return nil
    File.join(root, ENGINE_VIEWS, view_relative_path)
  end

  # The checkout's route files, joined (Jumpstart draws its routes from
  # config/routes/*.rb).
  def self.routes
    root = path or return nil
    (Dir.glob(File.join(root, "config/routes.rb")) + Dir.glob(File.join(root, "config/routes/**/*.rb")))
      .map { |file| File.read(file) }.join("\n")
  end

  # The English translations the checkout ships, merged into one Hash.
  def self.english
    root = path or return nil
    files = Dir.glob(File.join(root, "{config,lib/jumpstart/config}/locales/**/*.yml"))
    files.each_with_object({}) do |file, merged|
      data = YAML.safe_load_file(file, aliases: true, permitted_classes: [Symbol]) || {}
      deep_merge!(merged, data["en"]) if data.is_a?(Hash) && data["en"].is_a?(Hash)
    end
  end

  def self.deep_merge!(into, from)
    from.each do |key, value|
      into[key] = into[key].is_a?(Hash) && value.is_a?(Hash) ? deep_merge!(into[key], value) : value
    end
    into
  end
end
