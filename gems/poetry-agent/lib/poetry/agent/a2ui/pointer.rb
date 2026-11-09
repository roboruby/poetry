# frozen_string_literal: true

module Poetry
  module Agent
    module A2UI
      # JSON Pointer (RFC 6901) over plain Ruby documents, with A2UI's two
      # extensions: relative paths (no leading slash) resolve against a
      # collection scope, and an upsert writes through missing lists and
      # objects.
      #
      # @example
      #   Pointer.get({ "user" => { "name" => "Ada" } }, "/user/name") # => "Ada"
      #   Pointer.absolute("name", "/users/1")                       # => "/users/1/name"
      module Pointer
        # The largest array index a write may name, the spec's bound, so a
        # path cannot make the data model allocate an array of any size.
        MAX_INDEX = 10_000

        # Path segments a write never names: on a JavaScript renderer they
        # reach the object prototype, so the spec refuses them everywhere.
        FORBIDDEN = %w[__proto__ constructor prototype].freeze

        # A write the data model refuses (the spec's DataError).
        class Error < StandardError; end

        module_function

        # Splits a pointer into unescaped reference tokens; `""` and `"/"`
        # both name the whole document.
        #
        # @param path [String]
        # @return [Array<String>]
        def tokens(path)
          path = path.to_s
          return [] if path.empty? || path == "/"

          path.delete_prefix("/").split("/", -1).map { |token| token.gsub("~1", "/").gsub("~0", "~") }
        end

        # Joins tokens back into a pointer.
        #
        # @param parts [Array<String>]
        # @return [String]
        def build(parts)
          return "/" if parts.empty?

          "/#{parts.map { |part| part.to_s.gsub("~", "~0").gsub("/", "~1") }.join("/")}"
        end

        # Resolves a path against a scope: absolute paths pass through, a
        # relative one appends to the scope (the root when there is none), and
        # `""` or `.` names the scope itself; a scope's trailing slash is dropped.
        #
        # @param path [String]
        # @param scope [String, nil] the collection-item pointer in effect
        # @return [String] an absolute pointer
        def absolute(path, scope = nil)
          path = path.to_s
          return path if path.start_with?("/")

          base = scope.to_s
          base = base.delete_suffix("/") if base.length > 1
          return base.empty? ? "/" : base if path.empty? || path == "."

          "#{base unless base == "/"}/#{path}"
        end

        # Reads the value at a pointer; nil for any missing step (an array
        # takes only a canonical index: `0`, or digits without a leading zero).
        #
        # @param document [Object]
        # @param path [String]
        # @return [Object, nil]
        def get(document, path)
          tokens(path).reduce(document) do |node, token|
            case node
            when Hash then node[token]
            when Array then index?(token) ? node[token.to_i] : nil
            end
          end
        end

        # Writes a value at a pointer (A2UI upsert semantics): a missing step
        # becomes a list when the next token is an index and an object
        # otherwise, a nil value removes what the pointer names (an array keeps
        # its length, the slot reads null), and the whole-document pointer
        # replaces the document. A write through a primitive, a token that is not
        # an index on a list, an index past {MAX_INDEX}, and a forbidden segment
        # (`__proto__`, `constructor`, `prototype`) are refused.
        #
        # @param document [Hash, Array, nil]
        # @param path [String]
        # @param value [Object, nil]
        # @return [Object] the updated document
        # @raise [Error] for a write the data model refuses
        def upsert(document, path, value)
          parts = tokens(path)
          return value if parts.empty?

          forbidden = parts.find { |token| FORBIDDEN.include?(token) }
          raise Error, "Forbidden path segment '#{forbidden}' in path '#{path}'." if forbidden
          return document if value.nil? && get(document, path).nil?

          document = {} if document.nil?
          unless container?(document)
            raise Error,
                  "Cannot set path '#{path}': the data model root is a primitive value."
          end

          check!(document, parts, path)
          node = parts[0...-1].each_with_index.reduce(document) do |parent, (token, step)|
            child_for(parent, token, parts[step + 1], path)
          end
          value.nil? ? delete(node, parts.last) : store(node, parts.last, value, path)
          document
        end

        # Whether a token is a canonical array index.
        # @param token [String]
        # @return [Boolean]
        def index?(token)
          token.match?(/\A(0|[1-9]\d*)\z/)
        end

        # The container under a token on the way to a write, made when missing
        # (or null): a list when the next token is an index, else an object.
        def child_for(node, token, following, path)
          child = node.is_a?(Array) ? node[index(token, path)] : node[token]
          return child if container?(child)
          raise Error, "Cannot set path '#{path}': segment '#{token}' is a primitive value." unless child.nil?

          child = index?(following) ? [] : {}
          index(following, path) if child.is_a?(Array)
          store(node, token, child, path)
          child
        end

        # Writes a value at a token: an array appends on `-`, else sets its index; an object sets the key.
        def store(node, token, value, path)
          if node.is_a?(Array)
            token == "-" ? node.push(value) : node[index(token, path)] = value
          else
            node[token] = value
          end
        end

        # Removes a token's child: an object drops the key, a list keeps its
        # length and nulls the slot.
        # @api private
        def delete(node, token)
          return node.delete(token) unless node.is_a?(Array)

          node[token.to_i] = nil if index?(token) && token.to_i < node.size
        end

        # An array token as an index: canonical digits, at most {MAX_INDEX}.
        def index(token, path)
          raise Error, "Cannot use non-numeric segment '#{token}' on an array in path '#{path}'." unless index?(token)
          if token.to_i > MAX_INDEX
            raise Error,
                  "Cannot set path '#{path}': array index '#{token}' exceeds maximum supported index (#{MAX_INDEX})."
          end

          token.to_i
        end

        # Walks a write's path without changing anything and raises for the
        # first step the write would refuse, so a refused write leaves the
        # document as it was. A step past the document's end is a container the
        # write creates: a list when its token is an index.
        def check!(document, parts, path)
          node = document
          parts.each_with_index do |token, step|
            last = step == parts.size - 1
            if node.nil?
              index(token, path) if index?(token)
              next
            end
            next if last && node.is_a?(Array) && token == "-"

            child = node.is_a?(Array) ? node[index(token, path)] : node[token]
            break if last
            unless child.nil? || container?(child)
              raise Error,
                    "Cannot set path '#{path}': segment '#{token}' is a primitive value."
            end

            node = child
          end
        end

        # Whether a value holds children: an object or a list.
        def container?(value)
          value.is_a?(Hash) || value.is_a?(Array)
        end

        private_class_method :check!, :child_for, :store, :index, :container?
      end
    end
  end
end
