# frozen_string_literal: true

require "json"
require "digest"

# Flattens the vendored AG-UI 1.0 JSON Schema into the contract table
# poetry-agent's enforcement walker reads (config/agui/contract-1.0.json).
# Dev-only (rakelib never ships) and dependency-free. Same input,
# byte-identical output: the table is built in schema order, written with
# JSON.pretty_generate, and carries no timestamp. Everything the schema says
# that the walker cannot act on is either recorded as an annotation or makes
# the generator abort, so a new keyword or shape fails here instead of being
# enforced by accident.
module AguiContract
  # Every keyword the schema may use, and what the generator does with it.
  KEYWORDS = {
    "$schema" => :root, "$id" => :root, "title" => :root, "$defs" => :root,
    "$anchor" => :name, "description" => :dropped,
    "$ref" => :resolved, "allOf" => :merged, "oneOf" => :union,
    "type" => :assert, "properties" => :assert, "required" => :assert,
    "unevaluatedProperties" => :closes, "additionalProperties" => :opens,
    "const" => :assert, "enum" => :assert, "not" => :assert, "items" => :assert,
    "minimum" => :assert, "maximum" => :assert, "minItems" => :assert, "pattern" => :assert,
    "contentEncoding" => :annotation, "default" => :annotation
  }.freeze
  LEAF_TYPES = %w[string integer boolean].freeze

  class ContractError < StandardError; end

  # Aborts generation with a schema location and a reason.
  def self.fail!(where, message) = raise(ContractError, "#{where}: #{message}")

  # The keyword audit: counts each keyword in a schema position (property names,
  # definition names and const/enum/default values are data, not keywords).
  def self.audit(node, where, counts)
    return unless node.is_a?(Hash)

    node.each do |key, value|
      AguiContract.fail!(where, "unknown keyword #{key.inspect}") unless KEYWORDS.key?(key)
      counts[key] += 1
      case key
      when "$defs", "properties" then value.each { |name, sub| audit(sub, "#{where}/#{key}/#{name}", counts) }
      when "allOf", "oneOf" then value.each_with_index { |sub, i| audit(sub, "#{where}/#{key}/#{i}", counts) }
      when "items", "not" then audit(value, "#{where}/#{key}", counts)
      end
    end
  end

  class Generator
    # A generator over one parsed schema; its source file's path stamps the table.
    def initialize(schema, path)
      @path = path
      @schema = schema
      @raw = schema.fetch("$defs")
      @shapes = {} # def name => flattened shape (memo)
      @refs = Hash.new { |h, k| h[k] = [] } # def name => defs it names
      @raw.each do |name, body|
        unless body["$anchor"] == name
          AguiContract.fail!("#/$defs/#{name}",
                             "$anchor #{body["$anchor"].inspect} differs from its name")
        end
      end
    end

    # The definition a local $ref names, which must exist.
    def ref_name(ref, where)
      match = ref.match(%r{\A#/\$defs/([A-Za-z]+)\z}) or AguiContract.fail!(where, "unsupported $ref #{ref}")
      AguiContract.fail!(where, "dangling $ref #{ref}") unless @raw.key?(match[1])
      match[1]
    end

    # A definition's flattened shape, memoized; a definition that reaches itself aborts.
    def shape_of(name)
      @shapes[name] ||= begin
        @shapes[name] = :in_progress
        flatten(@raw.fetch(name), "#/$defs/#{name}", name)
      end
      AguiContract.fail!(name, "recursive definition") if @shapes[name] == :in_progress
      @shapes[name]
    end

    # A shape is inlined where it is referenced when it carries no structure the
    # walker descends into; objects with fields, unions and arrays stay named.
    def inlinable?(shape) = %w[leaf any].include?(shape["kind"]) || (shape["kind"] == "object" && shape["opaque"])

    # One schema node as a contract shape.
    def flatten(node, where, owner)
      AguiContract.fail!(where, "schema must be an object") unless node.is_a?(Hash)
      keys = node.keys - %w[description $anchor]
      shape =
        if node.key?("$ref")
          extra = keys - %w[$ref not default]
          AguiContract.fail!(where, "unsupported $ref siblings #{extra}") unless extra.empty?
          target = ref_name(node["$ref"], where)
          @refs[owner] << target
          resolved = shape_of(target)
          inlinable?(resolved) ? resolved.dup : { "ref" => target }
        elsif node.key?("oneOf")
          extra = keys - %w[oneOf]
          AguiContract.fail!(where, "unsupported oneOf siblings #{extra}") unless extra.empty?
          union(node["oneOf"], where, owner)
        elsif node.key?("allOf") || node.key?("properties") || node["type"] == "object"
          object(node, where, owner)
        elsif node["type"] == "array"
          extra = keys - %w[type items minItems]
          AguiContract.fail!(where, "unsupported array keywords #{extra}") unless extra.empty?
          array = { "kind" => "array", "items" => flatten(node.fetch("items"), "#{where}/items", owner) }
          array["min_items"] = node["minItems"] if node.key?("minItems")
          array
        elsif keys.intersect?(%w[type const enum])
          leaf(node, where)
        else
          extra = keys - %w[not default]
          AguiContract.fail!(where, "unsupported keywords #{extra} on an unconstrained schema") unless extra.empty?
          { "kind" => "any" }
        end
      if node.key?("not")
        unless node["not"].except("description") == { "type" => "null" }
          AguiContract.fail!(where,
                             "only {not: {type: null}} is supported")
        end
        AguiContract.fail!(where, "not-null on a #{shape["kind"] || "ref"} shape") unless shape["kind"] == "any"
        shape["not_null"] = true
      end
      shape["default"] = node["default"] if node.key?("default") # annotation: never applied
      shape
    end

    # A scalar schema as a leaf shape.
    def leaf(node, where)
      extra = node.keys - %w[description $anchor type const enum pattern minimum maximum contentEncoding default not]
      AguiContract.fail!(where, "unsupported leaf keywords #{extra}") unless extra.empty?
      shape = { "kind" => "leaf" }
      if node.key?("type")
        AguiContract.fail!(where, "unsupported type #{node["type"].inspect}") unless LEAF_TYPES.include?(node["type"])
        shape["type"] = node["type"]
      end
      if node.key?("const")
        AguiContract.fail!(where, "non-string const") unless node["const"].is_a?(String)
        shape["const"] = node["const"]
      end
      if node.key?("enum")
        unless node["enum"].all?(String) && node["enum"].uniq == node["enum"]
          AguiContract.fail!(where,
                             "enum must be distinct strings")
        end
        shape["enum"] = node["enum"]
      end
      if node.key?("pattern")
        AguiContract.fail!(where, "pattern on a non-string") unless shape["type"] == "string"
        shape["pattern"] = node["pattern"]
        shape["ruby_pattern"] = ruby_pattern(node["pattern"], where)
      end
      %w[minimum maximum].each do |bound|
        next unless node.key?(bound)

        unless shape["type"] == "integer" && node[bound].is_a?(Integer)
          AguiContract.fail!(where,
                             "#{bound} on a non-integer")
        end
        shape[bound] = node[bound]
      end
      shape["content_encoding"] = node["contentEncoding"] if node.key?("contentEncoding") # annotation in 2020-12
      shape
    end

    # ECMA-262 to Ruby. Only the subset this schema uses is accepted: one leading
    # ^ and one trailing $ (input anchors in ECMA, LINE anchors in Ruby, so they
    # become \A and \z), and otherwise literals, groups, alternation, quantifiers
    # and bracket classes with no escapes. Anything else aborts.
    def ruby_pattern(pattern, where)
      body = pattern.delete_prefix("^").delete_suffix("$")
      ok = pattern.start_with?("^") && pattern.end_with?("$") && !body.gsub("[^", "[").match?(/[\^$\\.]/)
      AguiContract.fail!(where, "pattern #{pattern.inspect} is outside the translatable subset") unless ok
      "\\A#{body}\\z"
    end

    # The properties and required names an object contributes, mixins included.
    def object_parts(node, where, owner)
      props = {}
      required = []
      Array(node["allOf"]).each_with_index do |sub, i|
        AguiContract.fail!("#{where}/allOf/#{i}", "allOf entries must be a bare $ref") unless sub.keys == ["$ref"]
        mixin_name = ref_name(sub["$ref"], where)
        @refs[owner] << mixin_name
        mixin = @raw.fetch(mixin_name)
        AguiContract.fail!(mixin_name, "a mixin must not close itself") if mixin.key?("unevaluatedProperties")
        mixin_props, mixin_required = object_parts(mixin, "#/$defs/#{mixin_name}", owner)
        mixin_props.each do |name, shape|
          props[name] = props.key?(name) ? intersect(props[name], shape, "#{where}/#{name}") : shape
        end
        required |= mixin_required
      end
      (node["properties"] || {}).each do |name, sub|
        shape = flatten(sub, "#{where}/properties/#{name}", owner)
        props[name] = props.key?(name) ? intersect(props[name], shape, "#{where}/properties/#{name}") : shape
      end
      required |= node.fetch("required", [])
      [props, required]
    end

    # An object schema as a closed or open shape, or opaque when it is open with no fields.
    def object(node, where, owner)
      extra = node.keys - %w[description $anchor type allOf properties required unevaluatedProperties
                             additionalProperties]
      AguiContract.fail!(where, "unsupported object keywords #{extra}") unless extra.empty?
      AguiContract.fail!(where, "type #{node["type"].inspect} with properties") unless [nil,
                                                                                        "object"].include?(node["type"])
      if node.key?("unevaluatedProperties") && node["unevaluatedProperties"] != false
        AguiContract.fail!(where, "unevaluatedProperties must be false")
      end
      if node.key?("additionalProperties") && node["additionalProperties"] != true
        AguiContract.fail!(where,
                           "additionalProperties must be true (a schema-valued one would close through a side door)")
      end
      closed = node["unevaluatedProperties"] == false
      AguiContract.fail!(where, "closed and open at once") if closed && node.key?("additionalProperties")
      props, required = object_parts(node, where, owner)
      required.each { |name| AguiContract.fail!(where, "required #{name} is not declared") unless props.key?(name) }
      if !closed && props.empty?
        { "kind" => "object", "opaque" => true } # open by key: checked as an object, never walked
      else
        { "kind" => "object", "closed" => closed, "props" => props, "required" => required }
      end
    end

    # Combines a mixin's field with the composing definition's own (allOf means
    # both apply). Only intersections with an exact answer are accepted.
    def intersect(left, right, where)
      return left if left == right
      return right.merge("not_null" => true) if left == { "kind" => "any",
                                                          "not_null" => true } && right["kind"] == "any"
      return right if left == { "kind" => "any" }
      return left if right == { "kind" => "any" }

      unless left["kind"] == "leaf" && right["kind"] == "leaf"
        AguiContract.fail!(where,
                           "cannot intersect #{left["kind"]} with #{right["kind"]}")
      end
      out = left.merge(right)
      AguiContract.fail!(where, "conflicting types") if left["type"] && right["type"] && left["type"] != right["type"]
      if left["const"] && right["const"] && left["const"] != right["const"]
        AguiContract.fail!(where,
                           "conflicting consts")
      end
      if left["pattern"] && right["pattern"] && left["pattern"] != right["pattern"]
        AguiContract.fail!(where,
                           "conflicting patterns")
      end
      out["enum"] = left["enum"] & right["enum"] if left["enum"] && right["enum"]
      if out["const"] && out["enum"]
        AguiContract.fail!(where, "const #{out["const"]} is outside the enum") unless out["enum"].include?(out["const"])
        out.delete("enum")
      end
      out["minimum"] = [left["minimum"], right["minimum"]].compact.max if left["minimum"] || right["minimum"]
      out["maximum"] = [left["maximum"], right["maximum"]].compact.min if left["maximum"] || right["maximum"]
      out
    end

    # A oneOf becomes a discriminated union when every option is a named object
    # with one required const field in common, all distinct; otherwise it must
    # be structural, with options of distinct JSON types.
    def union(options, where, owner)
      shapes = options.each_with_index.map { |o, i| flatten(o, "#{where}/oneOf/#{i}", owner) }
      if shapes.all? { |s| s.key?("ref") && shape_of(s["ref"])["kind"] == "object" && !shape_of(s["ref"])["opaque"] }
        members = shapes.map { |s| [s["ref"], shape_of(s["ref"])] }
        candidates = members.map do |_, m|
          m["props"].select { |field, f| m["required"].include?(field) && f["kind"] == "leaf" && f["const"] }.keys
        end.reduce(:&)
        found = candidates.select do |field|
          members.map do |_, m|
            m["props"][field]["const"]
          end.uniq.size == members.size
        end
        AguiContract.fail!(where, "no unique discriminator (candidates #{candidates})") unless found.size == 1
        field = found.first
        { "kind" => "union", "discriminator" => field,
          "members" => members.to_h { |name, m| [m["props"][field]["const"], name] } }
      else
        kinds = shapes.map { |s| json_kind(s) }
        unless kinds.uniq.size == kinds.size && kinds.none?(&:nil?)
          AguiContract.fail!(where,
                             "structural oneOf options share a JSON type: #{kinds}")
        end
        { "kind" => "oneof", "options" => kinds.zip(shapes).to_h }
      end
    end

    # The one JSON type a shape accepts, or nil when it has none.
    def json_kind(shape)
      return "object" if shape.key?("ref") && %w[object union].include?(shape_of(shape["ref"])["kind"])
      return "array" if shape.key?("ref") && shape_of(shape["ref"])["kind"] == "array"
      return shape["type"] if shape["kind"] == "leaf"

      %w[object array].include?(shape["kind"]) ? shape["kind"] : nil
    end

    # Whether the walker could find this whole value unrecognisable (a required
    # unknown union member, cascading). Arrays absorb drops, so they never do.
    def droppable?(shape, seen = {})
      return droppable?(shape_of(shape["ref"]), seen) if shape.key?("ref")

      case shape["kind"]
      when "union" then true
      when "object" then !shape["opaque"] && shape["required"].any? { |field| droppable?(shape["props"][field], seen) }
      when "oneof" then shape["options"].values.any? { |s| droppable?(s, seen) }
      else false
      end
    end

    # The definitions the roots reach by reference, in the order they are found.
    def reachable(roots)
      seen = []
      queue = roots.dup
      until queue.empty?
        name = queue.shift
        next if seen.include?(name)

        seen << name
        queue.concat(@refs[name])
      end
      seen
    end

    # The contract table: every definition flattened, the roots checked, reach and cascades recorded.
    def build
      @raw.each_key { |name| shape_of(name) }
      event = shape_of("Event")
      unless event["kind"] == "union" && event["discriminator"] == "type"
        AguiContract.fail!("Event",
                           "the root is not a union")
      end
      enum = shape_of("EventType")["enum"]
      AguiContract.fail!("Event", "EventType and the event union disagree") unless enum == event["members"].keys
      roots = event["members"].values + ["RunAgentInput"]
      roots.each { |name| AguiContract.fail!(name, "a root that can be dropped whole") if droppable?(shape_of(name)) }
      cascades = @shapes.select { |_, s| s["kind"] == "object" && droppable?(s) }.keys
      reach = reachable(%w[Event RunAgentInput])
      {
        "contract" => "agui-1.0",
        "schema_id" => @schema["$id"],
        "schema_sha256" => Digest::SHA256.hexdigest(File.binread(@path)),
        "roots" => { "event" => "Event", "input" => "RunAgentInput" },
        "reachable" => @raw.keys.select { |name| reach.include?(name) },
        "unreachable" => @raw.keys.reject { |name| reach.include?(name) },
        "cascading" => cascades,
        "defs" => @raw.keys.to_h { |name| [name, @shapes[name]] }
      }
    end
  end

  # The contract table for the schema at the path, as the committed JSON.
  def self.generate(schema_path)
    schema = JSON.parse(File.read(schema_path))
    audit(schema, "#", Hash.new(0))
    "#{JSON.pretty_generate(Generator.new(schema, schema_path).build)}\n"
  end
end
