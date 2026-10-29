# frozen_string_literal: true

module Poetry
  module Agent
    module A2UI
      # JSON Pointer (RFC 6901) over plain Ruby documents, with A2UI's two
      # extensions: relative paths (no leading slash) resolve against a
      # collection scope, and an upsert writes through missing objects.
      #
      # @example
      #   Pointer.get({ "user" => { "name" => "Ada" } }, "/user/name") # => "Ada"
      #   Pointer.absolute("name", "/users/1")                       # => "/users/1/name"
      module Pointer
        # The largest array index a write may name, the spec's bound, so a
        # path cannot make the data model allocate an array of any size.
        MAX_INDEX = 10_000

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

        # Resolves a path against a scope: absolute paths pass through,
        # relative ones append to the scope (the root when no scope).
        #
        # @param path [String]
        # @param scope [String, nil] the collection-item pointer in effect
        # @return [String] an absolute pointer
        def absolute(path, scope = nil)
          path = path.to_s
          return path if path.start_with?("/")
          return build(tokens(path)) if scope.nil? || scope.empty? || scope == "/"

          build(tokens(scope) + tokens(path))
        end

        # Reads the value at a pointer; nil for any missing step.
        #
        # @param document [Object]
        # @param path [String]
        # @return [Object, nil]
        def get(document, path)
          tokens(path).reduce(document) do |node, token|
            case node
            when Hash then node[token]
            when Array then token.match?(/\A\d+\z/) ? node[token.to_i] : nil
            end
          end
        end

        # Writes a value at a pointer (A2UI upsert semantics): missing
        # objects are created along the way, a nil value removes the key,
        # and the whole-document pointer replaces the document. An array
        # takes an index up to {MAX_INDEX}, or `-` to append.
        #
        # @param document [Hash, Array, nil]
        # @param path [String]
        # @param value [Object, nil]
        # @return [Object] the updated document
        # @raise [Error] for an array token that is not an index, or one past {MAX_INDEX}
        def upsert(document, path, value)
          parts = tokens(path)
          return value if parts.empty?

          document = {} unless document.is_a?(Hash) || document.is_a?(Array)
          node = document
          parts[0...-1].each do |token|
            child = child_of(node, token)
            unless child.is_a?(Hash) || child.is_a?(Array)
              child = {}
              store(node, token, child)
            end
            node = child
          end
          value.nil? ? delete(node, parts.last) : store(node, parts.last, value)
          document
        end

        # The child a pointer token names: an index into an array, a key into a hash.
        def child_of(node, token)
          node.is_a?(Array) ? node[token.to_i] : node[token]
        end

        # Writes a value at a pointer token: an array appends on the dash token, else sets the index or key.
        def store(node, token, value)
          if node.is_a?(Array)
            token == "-" ? node.push(value) : node[index(token)] = value
          else
            node[token] = value
          end
        end

        # Removes a token's child from a node, by index for an array (where
        # a token that is not an index names nothing).
        # @api private
        def delete(node, token)
          return node.delete(token) unless node.is_a?(Array)

          node.delete_at(token.to_i) if token.match?(/\A\d+\z/)
        end

        # An array token as an index: digits, at most {MAX_INDEX}.
        def index(token)
          raise Error, "#{token.inspect} is not an array index" unless token.match?(/\A\d+\z/)
          raise Error, "array index #{token} exceeds the maximum (#{MAX_INDEX})" if token.to_i > MAX_INDEX

          token.to_i
        end

        private_class_method :child_of, :store, :index
      end
    end
  end
end
