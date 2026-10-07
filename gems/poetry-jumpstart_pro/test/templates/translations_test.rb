# frozen_string_literal: true

require "test_helper"

# Every translation key a template looks up without a default: must exist in
# Jumpstart Pro's English locale (or Rails' own), resolving lazy ".key"
# lookups against the template's path the way Action View does. Runs against
# the private checkout, only when JUMPSTART_PRO_PATH points at it.
class TranslationsTest < Minitest::Test
  # A t(...) or I18n.t(...) call with a literal key.
  LOOKUP = /\b(?:I18n\.)?t\(\s*["']([.\w]+)["']/

  # Rails' own English defaults (errors.messages.*, number formats, ...).
  RAILS_LOCALES = %w[activemodel activesupport actionview].filter_map do |name|
    spec = Gem.loaded_specs[name] or next
    Dir.glob(File.join(spec.full_gem_path, "lib/**/locale/en.yml"))
  end.flatten.freeze

  def test_every_lookup_without_a_default_resolves
    english = JumpstartRepo.english or skip("set JUMPSTART_PRO_PATH to check against your Jumpstart Pro checkout")
    RAILS_LOCALES.each do |file|
      JumpstartRepo.deep_merge!(english, YAML.safe_load_file(file, aliases: true)["en"] || {})
    end

    missing = []
    TemplateTree.each do |category, relative|
      source = TemplateTree.read(category, relative)
      scopes = [scope_for(relative)] + source.scan(%r{render layout: "([\w/]+)"}).flatten.map do |layout|
        scope_for("#{layout}.html.erb", partial: true)
      end
      source.to_enum(:scan, LOOKUP).each do
        match = Regexp.last_match
        next if arguments(source, match.end(0)).include?("default:")

        key = match[1]
        candidates = key.start_with?(".") ? scopes.map { |scope| "#{scope}#{key}" } : [key]
        missing << "#{category}/#{relative}: #{key}" unless candidates.any? { |candidate| present?(english, candidate) }
      end
    end

    assert_empty missing, "translation keys missing from Jumpstart's English locale:\n  #{missing.join("\n  ")}"
  end

  private

  # The lazy lookup scope for a view path: users/sessions/new.html.erb is
  # users.sessions.new; application/_flash.html.erb is application.flash.
  def scope_for(relative, partial: false)
    directory, file = File.split(relative)
    name = file.sub(/\..*\z/, "")
    name = name.delete_prefix("_")
    name = name.delete_prefix("_") if partial
    [*directory.split("/"), name].reject { |part| part == "." }.join(".")
  end

  # The argument text of the call whose key ends at index, up to its
  # closing parenthesis.
  def arguments(source, index)
    depth = 1
    finish = index
    while finish < source.length && depth.positive?
      depth += 1 if source[finish] == "("
      depth -= 1 if source[finish] == ")"
      finish += 1
    end
    source[index...finish]
  end

  def present?(tree, dotted)
    dotted.split(".").reduce(tree) do |node, part|
      return false unless node.is_a?(Hash) && node.key?(part)

      node[part]
    end
    true
  end
end
