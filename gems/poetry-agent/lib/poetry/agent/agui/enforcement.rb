# frozen_string_literal: true

require "json"

module Poetry
  module Agent
    module AGUI
      # AG-UI 1.0 enforcement: unrecognised material is dropped or stripped
      # with a warning, a malformed known value is fatal. Driven only by the
      # contract table (config/agui/contract-1.0.json, generated from the
      # vendored 1.0 schema by `rake agui:contract`), one pass per event. It
      # mirrors the reference client's strip stage (what is stripped, where,
      # and the reported paths) and the validation that follows it (what is
      # fatal). Adapted from an MIT-licensed source (THIRD_PARTY_NOTICES.md).
      #
      # The input is never mutated; a value comes back as the same object when
      # nothing inside it changed (copy on write).
      #
      # @example
      #   walker = Poetry::Agent::AGUI::Enforcement::Walker.default
      #   event = walker.event(raw) { |warning| warnings << warning } # nil when the event is dropped
      #   input = walker.input(raw) { |warning| warnings << warning } # the outgoing RunAgentInput
      module Enforcement
        # A field the protocol describes, holding a value the schema rejects.
        class Malformed < ProtocolError
          # The schema keyword that failed (type, required, const, enum, ...).
          # @return [String]
          attr_reader :keyword

          # The JSON Pointer to the value.
          # @return [String]
          attr_reader :path

          # A rejection naming the keyword, the path and what was expected.
          # @param keyword [String]
          # @param path [String]
          # @param detail [String]
          # @param label [String, nil] the event type or definition being walked
          def initialize(keyword, path, detail, label = nil)
            @keyword = keyword
            @path = path
            where = path.empty? ? "(root)" : path
            super("Malformed #{label || "value"} at '#{where}': #{detail} (#{keyword})", stage: :enforcement)
          end
        end

        # The payload is larger than the enforcement budget.
        class LimitError < ProtocolError
          # A budget rejection.
          # @param message [String]
          def initialize(message) = super(message, stage: :enforcement)
        end

        # The contract and the walker disagree: unreachable unless the table changes.
        class ContractMismatch < StandardError; end

        # "This whole value is unrecognisable here."
        DROP = Object.new.freeze
        private_constant :DROP

        # A value's JSON kind, for messages.
        # @param value [Object]
        # @return [String]
        def self.kind(value)
          case value
          when nil then "null"
          when true, false then "boolean"
          when Integer, Float then "number"
          when String then "string"
          when Array then "array"
          when Hash then "object"
          else value.class.name
          end
        end

        # JSON Schema's integer: any number with a zero fractional part. Ruby parses
        # 1.0 as a Float, JavaScript as 1; both are the integer one.
        #
        # @param value [Object]
        # @return [Boolean]
        def self.integer?(value) = value.is_a?(Integer) || (value.is_a?(Float) && value.finite? && (value % 1).zero?)

        # Per-walk bookkeeping: the path to where the walk is, what was stripped,
        # and the entry budget.
        # @api private
        class State
          # The keys from the root to the value being walked.
          # @return [Array<String, Integer>]
          attr_reader :stack

          # The JSON pointers of what was stripped so far.
          # @return [Array<String>]
          attr_reader :stripped

          # Whether a null in an optional field reads as absent (the outgoing walk).
          # @return [Boolean]
          attr_reader :omit_nulls

          # The JSON Pointer of the first unrecognised value that removed what held it.
          # @return [String, nil]
          attr_reader :lost

          # A fresh walk with an entry budget, labelled for its rejections.
          def initialize(max, label, omit_nulls: false)
            @omit_nulls = omit_nulls
            @stack = []
            @stripped = []
            @used = 0
            @max = max
            @label = label
          end

          # The JSON Pointer to where the walk is, or to one key below it.
          def pointer(extra = nil)
            segments = extra.nil? ? @stack : [*@stack, extra]
            segments.map { |s| "/#{s.to_s.gsub("~", "~0").gsub("/", "~1")}" }.join
          end

          # Spends entries from the budget, refusing the walk once it runs out.
          def charge(entries)
            @used += entries
            raise LimitError, "Enforcement limit exceeded at '#{pointer}': more than #{@max} entries" if @used > @max
          end

          # Records a key below the current path as stripped.
          def strip(key) = @stripped << pointer(key)

          # Records the first unrecognised required value, whose container goes instead.
          def lose(key)
            @lost = pointer(key) if @lost.nil?
          end

          # A rejection at the current path, or at one key below it.
          def malformed(keyword, detail, key = nil) = Malformed.new(keyword, pointer(key), detail, @label)
        end

        # A string, integer or boolean, with its const, enum, pattern and bounds.
        # @api private
        class Leaf
          # A leaf checked against a shape's type, const, enum, pattern and bounds.
          def initialize(shape)
            @type = shape["type"]
            @const = shape["const"]
            @enum = shape["enum"]&.to_set&.freeze
            @pattern = shape["ruby_pattern"] && Regexp.new(shape["ruby_pattern"])
            @minimum = shape["minimum"]
            @maximum = shape["maximum"]
            @expected = shape["enum"]&.map(&:inspect)&.join("|")
            @closed_set = @enum if @enum&.all?(String) && [nil, "string"].include?(@type)
          end

          # Whether the node is checked without a descent.
          def leaf? = true

          # Whether a value is a string outside a closed set of strings (a role, a
          # subtype): a member added after this consumer shipped, which is
          # unrecognised material to strip, not a malformed value.
          def unrecognised?(value) = !@closed_set.nil? && value.is_a?(String) && !@closed_set.include?(value)

          # What the node expects, as a missing-field rejection names it.
          def expects = @type || (@const ? @const.inspect : "a string")

          # nil when the value is acceptable, else [keyword, detail].
          def check(value)
            case @type
            when "string" then unless value.is_a?(String)
                                 return ["type",
                                         "expected string, received #{Enforcement.kind(value)}"]
                               end
            when "integer"
              unless Enforcement.integer?(value)
                received = value.is_a?(Float) ? "a fractional number" : Enforcement.kind(value)
                return ["type", "expected int, received #{received}"]
              end
            when "boolean"
              unless [true, false].include?(value)
                return ["type",
                        "expected boolean, received #{Enforcement.kind(value)}"]
              end
            end
            return ["const", "expected #{@const.inspect}"] if @const && value != @const
            return ["enum", "expected one of #{@expected}"] if @enum && !@enum.include?(value)
            return ["pattern", "does not match #{@pattern.source}"] if @pattern && !@pattern.match?(value)
            return ["minimum", "expected number to be >=#{@minimum}"] if @minimum && value < @minimum
            return ["maximum", "expected number to be <=#{@maximum}"] if @maximum && value > @maximum

            nil
          end

          # The value itself, once it passes the check.
          def walk(value, state)
            error = check(value)
            raise state.malformed(*error) if error

            value
          end
        end

        # Any JSON value (state, rawEvent, a patch value, ...), optionally not null.
        # Opaque: never walked.
        # @api private
        class Any
          # A slot taking any value, or any value but null.
          def initialize(not_null) = @not_null = not_null

          # Whether the node is checked without a descent.
          def leaf? = true

          # Any value is described here, so none is unrecognised.
          def unrecognised?(_value) = false

          # What the node expects, as a missing-field rejection names it.
          def expects = "a value"

          # nil when the value is acceptable, else [keyword, detail].
          def check(value) = @not_null && value.nil? ? ["not", "expected a value other than null"] : nil

          # The value itself, unless it is a forbidden null.
          def walk(value, state)
            raise state.malformed("not", "expected a value other than null") if @not_null && value.nil?

            value
          end
        end

        # An object open by key (metadata, activity content, responseSchema): must
        # be an object, and its insides are data, so it is not walked.
        # @api private
        class OpaqueObject
          # Whether the node is checked without a descent.
          def leaf? = true

          # Its insides are data, so nothing in it is unrecognised.
          def unrecognised?(_value) = false

          # What the node expects, as a missing-field rejection names it.
          def expects = "object"

          # nil when the value is acceptable, else [keyword, detail].
          def check(value) = value.is_a?(Hash) ? nil : ["type", "expected object, received #{Enforcement.kind(value)}"]

          # The value itself, once it passes the check.
          def walk(value, state)
            error = check(value)
            raise state.malformed(*error) if error

            value
          end
        end

        # A described object. Closed ones strip undeclared keys; open ones (the
        # RFC 6902 operations, the mixins) keep them. Declared fields are walked.
        # @api private
        class ObjectNode
          # The declared fields, by name, filled once every definition exists.
          attr_writer :props

          # The names of the fields that must be present.
          attr_writer :required

          # Whether undeclared fields are stripped (an open object keeps them).
          attr_writer :closed

          # Whether the node is checked without a descent.
          def leaf? = false

          # What the node expects, as a missing-field rejection names it.
          def expects = "object"

          # The object with undeclared keys stripped (when closed) and declared fields walked, or DROP
          # when a required field turns out unrecognisable.
          def walk(value, state)
            unless value.is_a?(Hash)
              raise state.malformed("type",
                                    "expected object, received #{Enforcement.kind(value)}")
            end

            state.charge(value.size)
            out = nil
            pending = nil
            depth = state.stack.size
            # One flat pass per key: this is the walker's hot loop, and its
            # early exits (a required child removed) leave the whole object.
            value.each_pair do |key, child| # rubocop:disable Metrics/BlockLength
              node = @props[key]
              if node.nil?
                if @closed
                  state.strip(key)
                  out ||= copy_until(value, key)
                elsif out
                  out[key] = child
                end
                next
              end
              if node.leaf?
                if node.unrecognised?(child)
                  if @required.include?(key)
                    state.lose(key)
                    return DROP # cascade: the container goes instead
                  end

                  state.strip(key)
                  out ||= copy_until(value, key)
                  next
                end
                error = node.check(child)
                if error && child.nil? && state.omit_nulls && !@required.include?(key)
                  out ||= copy_until(value, key) # outgoing only: an optional null reads as absent
                  next
                end
                # Judged after the siblings: a required sibling that turns out to be
                # unrecognisable removes this whole object, and then nothing in it
                # was ever malformed (strip.ts strips before zod validates).
                pending ||= state.malformed(*error, key) if error
                out[key] = child if out
                next
              end
              state.stack.push(key)
              mark = state.stripped.size
              begin
                result = node.walk(child, state)
              rescue Malformed => e
                state.stack.slice!(depth..)
                state.stripped.slice!(mark..)
                if child.nil? && state.omit_nulls && !@required.include?(key)
                  out ||= copy_until(value, key)
                else
                  pending ||= e
                  out[key] = child if out
                end
                next
              end
              state.stack.pop
              if result.equal?(DROP)
                state.stripped.slice!(mark..) # nothing inside a removed value is reported
                return DROP if @required.include?(key) # cascade: the container goes instead

                state.strip(key)
                out ||= copy_until(value, key)
                next
              end
              if out
                out[key] = result
              elsif !result.equal?(child)
                out = copy_until(value, key)
                out[key] = result
              end
            end
            raise pending if pending

            result = out || value
            @required.each do |field|
              next if result.key?(field)

              expected = @props[field].expects
              raise state.malformed("required", "missing required '#{field}': expected #{expected}, received undefined")
            end
            result
          end

          private

          # The entries before `stop`, all unchanged so far.
          def copy_until(value, stop)
            copy = {}
            value.each_pair do |key, child|
              break if key == stop

              copy[key] = child
            end
            copy
          end
        end

        # A list: an unrecognisable element is dropped and the list survives.
        # @api private
        class ArrayNode
          # The node every element is walked with.
          attr_writer :items

          # The fewest elements the list may hold.
          attr_writer :min_items

          # Whether the node is checked without a descent.
          def leaf? = false

          # What the node expects, as a missing-field rejection names it.
          def expects = "array"

          # The list with each element walked and the unrecognisable ones dropped.
          def walk(value, state)
            unless value.is_a?(Array)
              raise state.malformed("type",
                                    "expected array, received #{Enforcement.kind(value)}")
            end

            state.charge(value.size)
            out = nil
            if @items.leaf?
              value.each_with_index do |entry, index|
                if @items.unrecognised?(entry)
                  state.strip(index)
                  out ||= value[0, index]
                  next
                end
                error = @items.check(entry)
                raise state.malformed(*error, index) if error

                out << entry if out
              end
            else
              value.each_with_index do |entry, index|
                state.stack.push(index)
                mark = state.stripped.size
                result = @items.walk(entry, state)
                state.stack.pop
                if result.equal?(DROP)
                  # The element goes whole, so the paths its descent named go with it.
                  state.stripped.slice!(mark..)
                  state.strip(index)
                  out ||= value[0, index]
                elsif out
                  out << result
                elsif !result.equal?(entry)
                  out = value[0, index]
                  out << result
                end
              end
            end
            result = out || value
            if @min_items && result.size < @min_items
              raise state.malformed("minItems", "expected array to have >=#{@min_items} items")
            end

            result
          end
        end

        # A oneOf discriminated by a const field. An object whose tag names no
        # member is unrecognised material (DROP); anything that is not an object is
        # a malformed value in a described slot, and stays fatal.
        # @api private
        class UnionNode
          # The field whose value picks the member.
          attr_writer :discriminator

          # The member node for each discriminator value.
          attr_writer :members

          # Whether the node is checked without a descent.
          def leaf? = false

          # What the node expects, as a missing-field rejection names it.
          def expects = "object"

          # The value walked as the member its tag names, or DROP for a tag naming none.
          def walk(value, state)
            unless value.is_a?(Hash)
              raise state.malformed("oneOf",
                                    "expected object, received #{Enforcement.kind(value)}")
            end

            member = @members[value[@discriminator]]
            return DROP if member.nil?

            member.walk(value, state)
          end
        end

        # A structural oneOf (string | list of parts): the option is picked by JSON
        # type; no option for the value's type is fatal.
        # @api private
        class OneOfNode
          # A choice among options keyed by JSON type.
          def initialize(options)
            @options = options
            @expected = options.keys.join(" | ")
          end

          # Whether the node is checked without a descent.
          def leaf? = false

          # What the node expects, as a missing-field rejection names it.
          def expects = @expected

          # The value walked by the option its JSON type picks.
          def walk(value, state)
            kind = Enforcement.kind(value)
            kind = "integer" if kind == "number" && Enforcement.integer?(value) && !@options.key?("number")
            node = @options[kind]
            raise state.malformed("oneOf", "expected #{@expected}, received #{kind}") if node.nil?

            node.walk(value, state)
          end
        end

        # The walker over a compiled contract table. It keeps no per-stream
        # state, so one instance serves every stream ({.default}).
        class Walker
          # The contract table that ships with the gem.
          DEFAULT_CONTRACT = File.expand_path("../../../../config/agui/contract-1.0.json", __dir__)
          # The entry budget: an event with more entries than this is refused.
          DEFAULT_MAX_ENTRIES = 1_000_000

          # The parsed contract table.
          # @return [Hash]
          attr_reader :table

          # A walker over a contract table file.
          # @param path [String]
          # @param max_entries [Integer] the entry budget per walk
          # @return [Walker]
          def self.load(path = DEFAULT_CONTRACT, max_entries: DEFAULT_MAX_ENTRIES)
            new(JSON.parse(File.read(path)), max_entries: max_entries)
          end

          # The shared walker over the shipped table.
          # @return [Walker]
          def self.default = @default ||= load

          # A walker over a parsed table.
          # @param table [Hash]
          # @param max_entries [Integer]
          def initialize(table, max_entries: DEFAULT_MAX_ENTRIES)
            @table = table
            @max = max_entries
            @named = {}
            defs = table.fetch("defs")
            # Two phases so references resolve to the shared node objects.
            defs.each { |name, shape| @named[name] = shell(shape) }
            defs.each { |name, shape| fill(@named[name], shape) } # rubocop:disable Style/CombinableLoops
            event = defs.fetch(table.dig("roots", "event"))
            @events = event.fetch("members").transform_values { |name| @named.fetch(name) }.freeze
            @input = @named.fetch(table.dig("roots", "input"))
          end

          # A compiled definition by name.
          # @param name [String]
          # @return [Object]
          # @api private
          def node(name) = @named.fetch(name)

          # The event types the contract describes.
          # @return [Array<String>]
          def event_types = @events.keys

          # One incoming event, after middleware: the value to deliver, nil when
          # the event is dropped. Each removal is reported to the block.
          #
          # @param raw [Hash]
          # @yieldparam warning [ProtocolWarning]
          # @return [Hash, nil]
          # @raise [Malformed] for a malformed known value
          def event(raw, &on_warning)
            unless raw.is_a?(Hash)
              raise Malformed.new("type", "", "an event must be a JSON object, received #{Enforcement.kind(raw)}")
            end

            type = raw["type"]
            node = @events[type]
            if node.nil?
              on_warning&.call(ProtocolWarning.new(
                kind: :unrecognised_event,
                message: "Dropping unrecognised event '#{type}': no middleware translated it and the " \
                         "protocol does not describe it."
              ))
              return nil
            end
            state = State.new(@max, type)
            value = node.walk(raw, state)
            if value.equal?(DROP)
              on_warning&.call(ProtocolWarning.new(
                kind: :stripped,
                message: "Dropping #{type}: its required '#{state.lost}' holds a value this implementation does " \
                         "not recognise."
              ))
              return nil
            end
            state.stripped.each do |path|
              on_warning&.call(ProtocolWarning.new(kind: :stripped,
                                                   message: "Removed unrecognised material at '#{path}' on #{type}."))
            end
            value
          end

          # The outgoing RunAgentInput, immediately before transmission. Like
          # enforceOutgoingInput, a null in an optional field is first read as
          # absent, silently (every optional field in 1.0 rejects null, so this only
          # ever removes a value that would otherwise be fatal).
          #
          # @param raw [Hash]
          # @param omit_optional_nulls [Boolean]
          # @yieldparam warning [ProtocolWarning]
          # @return [Hash]
          # @raise [Malformed] for a malformed known field, before anything is sent
          def input(raw, omit_optional_nulls: true, &on_warning)
            state = State.new(@max, "RunAgentInput", omit_nulls: omit_optional_nulls)
            value = root(@input, raw, state)
            state.stripped.each do |path|
              on_warning&.call(ProtocolWarning.new(
                kind: :stripped,
                message: "Removed unrecognised material at '#{path}' from the outgoing input."
              ))
            end
            value
          end

          # Any definition by anchor: the value and the paths stripped from it. A
          # value whose required field holds an unrecognised member of a closed
          # set is removed whole: nil, and that field's path.
          #
          # @param raw [Object]
          # @param name [String]
          # @return [Array(Object, Array<String>)]
          def definition(raw, name)
            state = State.new(@max, name)
            value = @named.fetch(name).walk(raw, state)
            return [nil, [state.lost]] if value.equal?(DROP)

            [value, state.stripped]
          end

          private

          # A root value walked; one found unrecognisable as a whole is a contract mismatch.
          def root(node, raw, state)
            value = node.walk(raw, state)
            # strip.ts throws here too: a value found unrecognisable as a whole has
            # no honest answer, and the generator proves no root can get here.
            raise ContractMismatch, "the walker found the whole value unrecognisable" if value.equal?(DROP)

            value
          end

          # An empty node for a definition, filled once every definition has one.
          def shell(shape)
            case shape["kind"]
            when "object" then shape["opaque"] ? OpaqueObject.new : ObjectNode.new
            when "array" then ArrayNode.new
            when "union" then UnionNode.new
            else compile(shape)
            end
          end

          # A shell node given its fields, items or members.
          def fill(node, shape)
            case node
            when ObjectNode
              node.props = shape.fetch("props").transform_values { |child| compile(child) }.freeze
              node.required = shape.fetch("required").freeze
              node.closed = shape.fetch("closed")
            when ArrayNode
              node.items = compile(shape.fetch("items"))
              node.min_items = shape["min_items"]
            when UnionNode
              node.discriminator = shape.fetch("discriminator")
              node.members = shape.fetch("members").transform_values { |name| @named.fetch(name) }.freeze
            end
          end

          # The node for an inline shape, or the shared node a reference names.
          def compile(shape)
            return @named.fetch(shape["ref"]) if shape.key?("ref")

            case shape["kind"]
            when "leaf" then Leaf.new(shape)
            when "any" then Any.new(shape["not_null"] == true)
            when "oneof" then OneOfNode.new(shape.fetch("options").transform_values { |option| compile(option) })
            when "object", "array", "union" then shell(shape).tap { |node| fill(node, shape) }
            else raise ContractMismatch, "unknown shape kind #{shape["kind"].inspect}"
            end
          end
        end
      end
    end
  end
end
