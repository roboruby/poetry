# frozen_string_literal: true

# Exports @poetry/controllers' JSDoc as the JSON the docs site renders at
# /api - the JS sibling of export_yard.rb, emitting the SAME schema so the
# /api views, markdown mirror, and search palette need no JS-specific code.
#
#   ruby script/export_jsdoc.rb <poetry-core_root> <out.json>
#
# Sources joined per controller:
# - the file's header narration (the first contiguous // block) as the
#   object docstring, plus a facts section from config/controllers_manifest.json
#   (targets / values / events - the introspected machine truth);
# - the JSDoc /** */ block above each public method for the method entries.
# Helper modules export functions/constants/classes documented with JSDoc
# directly. vendor/ is upstream-faithful and skipped.
#
# The export doubles as a drift gate: an exported symbol or a public class
# method WITHOUT documentation aborts the run, listing the offenders - the
# JS twin of the yard gates. (Object-literal members, e.g. the typeahead
# factory's instance, are described by their factory's @returns and not
# exported individually.)

require "json"

gem_root, out_path = ARGV
abort "usage: export_jsdoc.rb <poetry-core_root> <out.json>" unless gem_root && out_path

JS_ROOT = File.join(gem_root, "app/javascript/poetry/core")
MANIFEST = JSON.parse(File.read(File.join(gem_root, "config/controllers_manifest.json")))

# Superclasses among the controllers themselves (extends Controller is the
# Stimulus base and renders as no superclass).
SUPERCLASS_IDENTIFIERS = { "DialogController" => "poetry--core--dialog" }.freeze

@errors = []

# --- JSDoc block -> {docstring, params, return} -----------------------------

def parse_jsdoc(block)
  content = block.map { |line| line.sub(%r{\A\s*/?\*+/?\s?}, "").sub(%r{\s*\*+/\z}, "").rstrip }
  description = []
  tags = []
  content.each do |line|
    if line.start_with?("@")
      tags << line
    elsif tags.any?
      tags[-1] = "#{tags.last} #{line.strip}"
    else
      description << line
    end
  end

  params = []
  ret = nil
  extra = []
  tags.each do |tag|
    case tag
    when /\A@param\s+(?:\{([^}]*)\}\s*)?(\S+)(?:\s+-?\s*(.*))?\z/m
      params << { "name" => Regexp.last_match(2), "types" => [Regexp.last_match(1)].compact,
                  "text" => tidy(Regexp.last_match(3).to_s) }
    when /\A@returns?\s+(?:\{([^}]*)\}\s*)?(.*)\z/m
      ret = { "types" => [Regexp.last_match(1)].compact, "text" => tidy(Regexp.last_match(2).to_s) }
    when /\A@throws\s+(?:\{([^}]*)\}\s*)?(.*)\z/m
      extra << "Raises `#{Regexp.last_match(1)}` - #{tidy(Regexp.last_match(2).to_s)}"
    when /\A@type\b/
      nil # constants carry the declaration itself
    else
      @errors << "unknown JSDoc tag: #{tag[0, 60]}"
    end
  end

  docstring = tidy(description.join("\n").strip)
  docstring = [docstring, *extra].reject(&:empty?).join("\n\n")
  { "docstring" => docstring, "params" => params, "return" => ret }
end

# {@link X} has no cross-page target here - render as code.
def tidy(text) = text.gsub(/\{@link\s+([^}]+)\}/) { "`#{Regexp.last_match(1).strip}`" }.strip

# --- declarations -----------------------------------------------------------

# Collect a possibly multi-line declaration head until its parens balance.
def signature_at(lines, index)
  signature = lines[index].dup
  depth = signature.count("(") - signature.count(")")
  while depth.positive? && (index += 1) < lines.length
    signature << " " << lines[index].strip
    depth += lines[index].count("(") - lines[index].count(")")
  end
  signature.sub(/\s*\{\s*\z/, "").gsub(/\s+/, " ").strip
end

def clean_signature(raw)
  raw.sub(/\Aexport\s+(default\s+)?/, "").sub(/\A(async|get|static)\s+/, "")
     .sub(/\Afunction\s+/, "")
end

# The first contiguous // block in the file - every file's narration header.
def header_narration(lines)
  start = lines.index { |line| line.start_with?("//") }
  return "" unless start

  block = lines[start..].take_while { |line| line.start_with?("//") }
  tidy(block.map { |line| line.sub(%r{\A// ?}, "") }.join("\n").strip)
end

def method_entry(parsed, name, signature, scope, file, line)
  { "name" => name, "scope" => scope, "group" => nil, "signature" => signature,
    "docstring" => parsed["docstring"], "params" => parsed["params"],
    "return" => parsed["return"], "examples" => [], "file" => file, "line" => line }
end

# --- one file ---------------------------------------------------------------

METHOD_DEF = /\A  (?:async |get |static )?([a-z]\w*)\s*\(/i
EXPORT_SKIP = /\Aexport (\{|\*)/ # re-exports document nothing themselves

def scan(path)
  lines = File.readlines(path, chomp: true)
  file = "app/javascript/poetry/core/#{path.delete_prefix("#{JS_ROOT}/")}"
  result = { file: file, header: header_narration(lines),
             functions: [], constants: [], classes: [], controller_methods: [],
             extends: nil }
  klass = nil # {name:, methods: []} while inside export(ed) class

  i = 0
  while i < lines.length
    line = lines[i]

    if (match = line.match(%r{\A(\s{0,2})/\*\*}))
      indent = match[1]
      block = [line]
      block << lines[i += 1] until lines[i].include?("*/")
      i += 1
      i += 1 while lines[i].to_s.strip.empty?
      decl = lines[i]
      parsed = parse_jsdoc(block)
      handle_decl(result, klass, parsed, decl, lines, i, indent, file)
      i += 1
      next
    end

    case line
    when /\Aexport default class(?:\s+(\w+))?\s+extends\s+(\w+)/
      klass = { name: Regexp.last_match(1), controller: true }
      result[:extends] = Regexp.last_match(2)
    when /\Aexport class (\w+)/
      @errors << "#{file}:#{i + 1}: export class #{Regexp.last_match(1)} lacks JSDoc"
    when /\Aexport (function|const) (\w+)/
      @errors << "#{file}:#{i + 1}: export #{Regexp.last_match(2)} lacks JSDoc" unless line.match?(EXPORT_SKIP)
    when METHOD_DEF
      # A public method with no preceding JSDoc - but only inside a class
      # body, and never a field assignment or a private #member.
      if klass && !line.include?("=") && lines[i - 1].to_s.strip != "*/"
        @errors << "#{file}:#{i + 1}: public method #{Regexp.last_match(1)} lacks JSDoc"
      end
    end

    klass = nil if klass && line == "}"
    i += 1
  end

  result
end

def handle_decl(result, klass, parsed, decl, lines, index, indent, file)
  line_number = index + 1
  case decl
  when /\Aexport function (\w+)/
    result[:functions] << method_entry(parsed, Regexp.last_match(1),
                                       clean_signature(signature_at(lines, index)), "class", file, line_number)
  when /\Aexport const (\w+)\s*=\s*(.*)\z/
    result[:constants] << { "name" => Regexp.last_match(1),
                            "value" => Regexp.last_match(2)[0, 200],
                            "docstring" => parsed["docstring"] }
  when /\Aexport class (\w+)/
    result[:classes] << { name: Regexp.last_match(1), docstring: parsed["docstring"],
                          line: line_number, methods: [] }
  when METHOD_DEF
    name = Regexp.last_match(1)
    signature = clean_signature(signature_at(lines, index))
    entry = method_entry(parsed, name, signature, "instance", file, line_number)
    if klass&.dig(:controller)
      result[:controller_methods] << entry
    elsif result[:classes].any? && indent == "  "
      result[:classes].last[:methods] << entry
    else
      @errors << "#{file}:#{line_number}: documented method #{name} outside a known class"
    end
  else
    @errors << "#{file}:#{line_number}: JSDoc above unrecognized declaration: #{decl.to_s[0, 60]}"
  end
end

# --- manifest facts ---------------------------------------------------------

def facts_for(identifier)
  entry = MANIFEST[identifier] or return nil
  parts = []
  if entry["targets"].any?
    parts << "**Targets**: #{entry["targets"].map { |t| "`#{t}`" }.join(", ")}"
  end
  if entry["values"].any?
    values = entry["values"].map do |name, definition|
      default = definition.key?("default") ? ", default: #{definition["default"].inspect}" : ""
      "`#{name}` (#{definition["type"]}#{default})"
    end
    parts << "**Values**: #{values.join("; ")}"
  end
  parts << "**Classes**: #{entry["classes"].map { |c| "`#{c}`" }.join(", ")}" if entry["classes"].any?
  parts << "**Events**: #{entry["events"].map { |e| "`#{e}`" }.join(", ")}" if entry["events"].any?
  parts.join("\n\n")
end

# --- assemble ---------------------------------------------------------------

objects = []

Dir[File.join(JS_ROOT, "**/*.js")].sort.each do |path|
  next if path.include?("/vendor/")

  scanned = scan(path)
  basename = File.basename(path, ".js")

  if basename == "index"
    objects << { "path" => "@poetry/controllers", "type" => "module", "superclass" => nil,
                 "docstring" => scanned[:header], "examples" => [], "file" => scanned[:file],
                 "methods" => scanned[:functions], "constants" => scanned[:constants] }
  elsif path.include?("/helpers/")
    objects << { "path" => "@poetry/controllers/helpers/#{basename}", "type" => "module",
                 "superclass" => nil, "docstring" => scanned[:header], "examples" => [],
                 "file" => scanned[:file], "methods" => scanned[:functions],
                 "constants" => scanned[:constants] }
    scanned[:classes].each do |klass|
      objects << { "path" => klass[:name], "type" => "class", "superclass" => nil,
                   "docstring" => "#{klass[:docstring]}\n\nExported from " \
                                  "`@poetry/controllers/helpers/#{basename}`.",
                   "examples" => [], "file" => scanned[:file],
                   "methods" => klass[:methods], "constants" => [] }
    end
  else
    identifier = "poetry--core--#{basename.delete_suffix("_controller").tr("_", "-")}"
    unless MANIFEST.key?(identifier)
      warn "export_jsdoc: #{identifier} has no manifest entry (not in the registered " \
           "controllers map) - exported without the facts section"
    end

    docstring = [scanned[:header], facts_for(identifier)].compact.reject(&:empty?).join("\n\n")
    objects << { "path" => identifier, "type" => "controller",
                 "superclass" => SUPERCLASS_IDENTIFIERS[scanned[:extends]],
                 "docstring" => docstring, "examples" => [], "file" => scanned[:file],
                 "methods" => scanned[:controller_methods], "constants" => [] }
  end
end

if @errors.any?
  warn "export_jsdoc: #{@errors.length} problem(s):"
  @errors.each { |error| warn "  #{error}" }
  abort
end

objects.sort_by! { |o| o["path"] }
File.write(out_path, JSON.pretty_generate("gem" => "@poetry/controllers", "objects" => objects))
puts "#{out_path}: #{objects.length} objects"
