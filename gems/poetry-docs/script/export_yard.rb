# frozen_string_literal: true

# Exports a gem's YARD registry as the JSON the docs site renders at /api.
#
# Runs INSIDE the target gem's bundle (so .yardopts, the custom handler kit,
# and the gem's own doc conventions all apply):
#
#   cd <gem_root> && BUNDLE_GEMFILE=Gemfile bundle exec ruby \
#     <docs_root>/script/export_yard.rb <gem_root> <out.json>
#
# The export is consumer-scoped: private-visibility methods, @api private
# objects, and undocumented plumbing are dropped here so the site never has
# to re-derive that filtering.

require "yard"
require "json"

gem_root, out_path = ARGV
abort "usage: export_yard.rb <gem_root> <out.json>" unless gem_root && out_path

Dir.chdir(gem_root) do
  YARD::Registry.clear
  YARD::CLI::Yardoc.run("--no-output", "--no-progress", "--no-stats", "--no-cache")
end

def api_private?(object)
  object.has_tag?(:api) && object.tag(:api).text == "private"
end

def examples(object)
  object.tags(:example).map { |t| { "title" => t.name.to_s, "text" => t.text.to_s } }
end

def params(object)
  object.tags(:param).map { |t| { "name" => t.name.to_s, "types" => Array(t.types), "text" => t.text.to_s } }
end

def returns(object)
  t = object.tag(:return)
  t ? { "types" => Array(t.types), "text" => t.text.to_s } : nil
end

def method_entry(m)
  {
    "name" => m.name.to_s,
    "scope" => m.scope.to_s,
    "group" => m.group&.to_s,
    "signature" => m.signature.to_s.sub(/\Adef +/, ""),
    "docstring" => m.docstring.to_s,
    "params" => params(m),
    "return" => returns(m),
    "examples" => examples(m),
    "file" => m.file.to_s,
    "line" => m.line
  }
end

objects = YARD::Registry.all(:class, :module).select do |o|
  o.path.start_with?("Poetry", "ActiveModel") && !api_private?(o) &&
    !o.path.include?("Preview") && o.file
end

payload = objects.sort_by(&:path).map do |o|
  methods = o.meths(inherited: false, included: false)
             .select { |m| m.visibility == :public && !api_private?(m) }
             .reject { |m| m.docstring.blank? && m.tags.empty? }
             .sort_by { |m| [ m.scope.to_s, m.name.to_s ] }
             .map { |m| method_entry(m) }

  constants = o.constants(inherited: false)
               .select { |c| c.visibility == :public && !api_private?(c) && !c.docstring.blank? }
               .sort_by { |c| c.name.to_s }
               .map { |c| { "name" => c.name.to_s, "value" => c.value.to_s[0, 200], "docstring" => c.docstring.to_s } }

  next nil if methods.empty? && constants.empty? && o.docstring.blank?

  {
    "path" => o.path,
    "type" => o.type.to_s,
    "superclass" => (o.type == :class ? o.superclass&.path : nil),
    "docstring" => o.docstring.to_s,
    "examples" => examples(o),
    "file" => o.file.to_s,
    "methods" => methods,
    "constants" => constants
  }
end.compact

File.write(out_path, JSON.pretty_generate(
                       "gem" => File.basename(File.expand_path(gem_root)),
                       "objects" => payload
                     ))
puts "#{out_path}: #{payload.length} objects"
