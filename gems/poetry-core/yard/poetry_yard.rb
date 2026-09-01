# frozen_string_literal: true

# YARD extensions for poetry's declarative surfaces. Loaded from .yardopts
# via `--load` at doc-build time only - never required at runtime, never
# shipped into an app.
#
# What vanilla YARD cannot see, and what each handler projects:
#
# - `class_methods do` / `included do` (ActiveSupport::Concern): parsed
#   through, so the DSL macros' docblocks and concern-declared slots publish.
# - `option` / `style`: each declaration defines a reader at class load;
#   the handler registers it with the declaration's comment plus the
#   machine facts (type, default, variants, required).
# - `validates ... inclusion:` amends the matching option's entry with its
#   allowed values.
# - `renders_one` / `renders_many`: the slot reader and `with_*` writer(s),
#   including polymorphic `types:` unions (one writer per `as:` name).
# - `part`: collected into an Anatomy section appended to the class docstring.

require "active_support/core_ext/string/inflections"

# The kit can be --load'ed more than once per invocation; a second load
# would only re-define everything.
return if defined?(PoetryYard)

module PoetryYard
  TYPE_MAP = {
    "string" => "String", "symbol" => "Symbol", "boolean" => "Boolean",
    "integer" => "Integer", "numeric" => "Numeric", "float" => "Float",
    "hash" => "Hash", "list" => "Array", "array" => "Array",
    "proc" => "Proc", "date" => "Date", "time" => "Time"
  }.freeze

  # Namespaces that already carry the Anatomy heading this run.
  ANATOMY_SEEN = Set.new

  # slot_doc strings recorded ahead of their renders_* declarations
  # (the away-from-declaration form; the common form is the doc: keyword
  # on the declaration itself), keyed [namespace path, slot name].
  SLOT_DOCS = {} # rubocop:disable Style/MutableConstant -- build-time registry, handler-mutated

  module_function

  # A string literal or backslash-continued string concat -> its text.
  def string_text(node)
    return nil unless node.respond_to?(:type) && %i[string_literal string_concat].include?(node.type)

    parts = []
    collect = lambda do |n|
      parts << n.source if n.respond_to?(:type) && n.type == :tstring_content
      n.children.each { |c| collect.call(c) if c.respond_to?(:children) }
    end
    collect.call(node)
    parts.join
  rescue StandardError
    nil
  end

  # The declaration's prose: the doc: keyword when present, else the
  # comment directly above the statement.
  def declaration_doc(statement, keywords)
    string_text(keywords["doc"]) || comment_text(statement)
  end

  # ":name" / ":\"icon-xs\"" / "\"name\"" -> "name"; nil when not a literal.
  def literal_name(node)
    return nil unless node

    src = node.source.strip
    return src[1..].delete(%q("')) if src.start_with?(":")
    return src.delete(%q("')) if src.start_with?('"', "'")

    nil
  end

  # The trailing keyword arguments of a method_call, as label => value-node.
  # Depending on the parser generation they arrive as a :bare_assoc_hash or
  # as a plain :list of :assoc nodes.
  def kwargs(statement)
    hash = statement.parameters.find do |n|
      next false unless n.respond_to?(:type)
      next true if n.type == :bare_assoc_hash

      n.type == :list && n.children.any? &&
        n.children.all? { |c| c.respond_to?(:type) && c.type == :assoc }
    end
    return {} unless hash

    hash.children.each_with_object({}) do |assoc, out|
      next unless assoc.respond_to?(:type) && assoc.type == :assoc

      label = assoc.children.first.source.to_s.delete_suffix(":").delete_prefix(":")
      out[label] = assoc.children[1]
    end
  rescue StandardError
    {}
  end

  # %i[a b] / [:a, :b] / a CONST resolved in namespace -> "a, b" (or raw source).
  def values_text(node, namespace)
    return nil unless node

    src = node.source.strip
    if %i[var_ref const_path_ref top_const_ref].include?(node.type)
      const = YARD::Registry.resolve(namespace, src, true)
      src = const.value.to_s.strip if const.is_a?(YARD::CodeObjects::ConstantObject) && const.value
    end
    list = src[/%i\[([^\]]*)\]/, 1]
    return list.split.join(", ") if list

    if src.start_with?("[")
      syms = src.scan(/:"?([\w-]+)"?/).flatten
      return syms.join(", ") if syms.any?
    end
    src
  rescue StandardError
    node.source.strip
  end

  def return_type(type_name)
    TYPE_MAP.fetch(type_name.to_s, "Object")
  end

  def register_dynamic(handler, name, text, group)
    ns = handler.namespace
    existing = YARD::Registry.at("#{ns.path}##{name}")
    return existing if existing # a hand-written def owns the name

    obj = YARD::CodeObjects::MethodObject.new(ns, name)
    handler.send(:register, obj)
    obj.dynamic = true
    obj.group = group
    obj.docstring = text
    obj
  rescue StandardError
    nil
  end

  def comment_text(statement)
    c = statement.comments
    c.respond_to?(:join) ? c.join("\n").strip : c.to_s.strip
  end
end

# `class_methods do` - parse the block as class-scope methods of the concern.
class PoetryClassMethodsHandler < YARD::Handlers::Ruby::Base
  handles method_call(:class_methods)
  namespace_only

  def process
    parse_block(statement.last.last, namespace: namespace, scope: :class)
  rescue StandardError
    nil
  end
end

# `included do` - parse through so concern-declared slots/options register
# (on the concern module; mixin listings carry them onto includers).
class PoetryIncludedHandler < YARD::Handlers::Ruby::Base
  handles method_call(:included)
  namespace_only

  def process
    return unless namespace.path.start_with?("Poetry")

    parse_block(statement.last.last, namespace: namespace, scope: :instance)
  rescue StandardError
    nil
  end
end

# `option :name, :type, default: ..., required: ..., format: ...`
class PoetryOptionHandler < YARD::Handlers::Ruby::Base
  handles method_call(:option)
  namespace_only

  def process
    return unless namespace.path.start_with?("Poetry")

    name = PoetryYard.literal_name(statement.parameters.first)
    return unless name

    type = PoetryYard.literal_name(statement.parameters[1]) || "object"
    kw = PoetryYard.kwargs(statement)

    facts = ["Constructor option `#{name}:`."]
    tail = []
    tail << "defaults to `#{kw["default"].source.strip.gsub(/\s+/, " ")}`" if kw["default"]
    tail << "required" if kw["required"]&.source&.strip == "true"
    tail << "format: `#{kw["format"].source.strip}`" if kw["format"]

    text = [PoetryYard.declaration_doc(statement, kw), facts.join(" "),
            "@return [#{PoetryYard.return_type(type)}] #{tail.join("; ")}".strip]
           .reject(&:empty?).join("\n\n")
    PoetryYard.register_dynamic(self, name, text, "Options")
  end
end

# `style :name, default: ..., variants: ..., required: ...`
class PoetryStyleHandler < YARD::Handlers::Ruby::Base
  handles method_call(:style)
  namespace_only

  def process
    return unless namespace.path.start_with?("Poetry")

    name = PoetryYard.literal_name(statement.parameters.first)
    return unless name

    kw = PoetryYard.kwargs(statement)

    tail = []
    if (variants = PoetryYard.values_text(kw["variants"], namespace))
      tail << "one of: `#{variants}`"
    end
    tail << "defaults to `#{kw["default"].source.strip}`" if kw["default"]

    text = [PoetryYard.declaration_doc(statement, kw), "Style axis `#{name}:`.",
            "@return [Symbol] #{tail.join("; ")}".strip]
           .reject(&:empty?).join("\n\n")
    PoetryYard.register_dynamic(self, name, text, "Style axes")
  end
end

# `slot_doc :name, "..."` - recorded for the renders_* declaration that
# follows; also the registry's slot-description source.
class PoetrySlotDocHandler < YARD::Handlers::Ruby::Base
  handles method_call(:slot_doc)
  namespace_only

  def process
    return unless namespace.path.start_with?("Poetry")

    name = PoetryYard.literal_name(statement.parameters.first)
    text = PoetryYard.string_text(statement.parameters[1])
    PoetryYard::SLOT_DOCS[[namespace.path, name]] = text if name && text
  end
end

# `validates :name, inclusion: { in: VALUES }` - amend the option's entry.
class PoetryValidatesHandler < YARD::Handlers::Ruby::Base
  handles method_call(:validates)
  namespace_only

  def process
    return unless namespace.path.start_with?("Poetry")

    name = PoetryYard.literal_name(statement.parameters.first)
    return unless name

    inclusion = PoetryYard.kwargs(statement)["inclusion"]
    return unless inclusion.respond_to?(:type)

    in_node = nil
    if %i[hash bare_assoc_hash].include?(inclusion.type)
      inclusion.children.each do |assoc|
        next unless assoc.respond_to?(:type) && assoc.type == :assoc

        in_node = assoc.children[1] if assoc.children.first.source.to_s.start_with?("in")
      end
    end
    return unless in_node

    obj = YARD::Registry.at("#{namespace.path}##{name}")
    return unless obj&.dynamic

    values = PoetryYard.values_text(in_node, namespace)
    return if values.nil? || obj.docstring.all.include?("one of:")

    obj.docstring = obj.docstring.all.sub(/^@return \[[^\]]+\]/) { |m| "#{m} one of: `#{values}`;" }
  rescue StandardError
    nil
  end
end

# `renders_one :name` / `renders_many :names` with the declaration
# keywords - doc: (the docstring), renders: (ignored here; the callable),
# and the polymorphic `types: { key: { as: :writer } }`.
class PoetrySlotHandler < YARD::Handlers::Ruby::Base
  handles method_call(:renders_one), method_call(:renders_many)
  namespace_only

  def process
    return unless namespace.path.start_with?("Poetry")

    name = PoetryYard.literal_name(statement.parameters.first)
    return unless name

    many = statement.method_name(true) == :renders_many
    comment = PoetryYard::SLOT_DOCS[[namespace.path, name]] ||
              PoetryYard.string_text(PoetryYard.kwargs(statement)["doc"]) ||
              PoetryYard.comment_text(statement)

    reader_text = [comment,
                   many ? "Slot collection: the rendered `#{name}` set." : "Slot: the rendered `#{name}` content.",
                   "@return [#{many ? "Array" : "Object"}]"]
                  .reject(&:empty?).join("\n\n")
    PoetryYard.register_dynamic(self, name, reader_text, "Slots")

    writer_names = polymorphic_writers
    writer_names = [(many ? "with_#{name.singularize}" : "with_#{name}")] if writer_names.empty?
    writer_names.each do |writer|
      text = [comment,
              "Slot writer for the `#{name}` slot#{" (repeatable)" if many}.",
              "@return [void]"].reject(&:empty?).join("\n\n")
      PoetryYard.register_dynamic(self, writer, text, "Slots")
    end
  end

  private

  # types: { key: { renders: ..., as: :writer } } -> ["with_writer", ...]
  def polymorphic_writers
    types = PoetryYard.kwargs(statement)["types"]
    return [] unless types.respond_to?(:type) && types.type == :hash

    types.children.filter_map do |assoc|
      next unless assoc.respond_to?(:type) && assoc.type == :assoc

      key = assoc.children.first.source.to_s.delete_suffix(":").delete_prefix(":")
      value = assoc.children[1]
      as = nil
      if value.respond_to?(:type) && value.type == :hash
        value.children.each do |inner|
          next unless inner.respond_to?(:type) && inner.type == :assoc

          as = PoetryYard.literal_name(inner.children[1]) if inner.children.first.source.to_s.start_with?("as")
        end
      end
      "with_#{as || key}"
    end
  rescue StandardError
    []
  end
end

# `part "name", "description", states: ..., vars: ...` - appended to the
# class docstring as an Anatomy section.
class PoetryPartHandler < YARD::Handlers::Ruby::Base
  handles method_call(:part)
  namespace_only

  def process
    return unless namespace.path.start_with?("Poetry")

    name = PoetryYard.literal_name(statement.parameters.first)
    return unless name

    desc = statement.parameters[1]
    desc_text = string_text(desc)
    unless PoetryYard::ANATOMY_SEEN.include?(namespace.path)
      PoetryYard::ANATOMY_SEEN << namespace.path
      namespace.docstring = "#{namespace.docstring.all}\n\n**Anatomy** (`data-slot` parts):\n"
    end
    line = desc_text ? "- `#{name}` - #{desc_text.gsub(/\s+/, " ")}" : "- `#{name}`"
    namespace.docstring = "#{namespace.docstring.all}\n#{line}"
  rescue StandardError
    nil
  end

  private

  def string_text(node)
    PoetryYard.string_text(node)
  end
end
