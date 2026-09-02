# frozen_string_literal: true

module Poetry
  module Agent
    module AGUI
      # RFC 6902 JSON Patch over plain Ruby data (Hash / Array), with RFC
      # 6901 JSON Pointer paths - what AG-UI's STATE_DELTA and
      # ACTIVITY_DELTA carry. Applies atomically: the document is deep-
      # copied first and the copy is returned, so a failing operation
      # leaves the caller's document untouched.
      module JsonPatch
        # Raised for an operation the document cannot take (an unknown
        # op, a missing path, a failed test).
        class Error < Poetry::Core::Error; end

        module_function

        # Applies a patch and returns the patched copy.
        #
        # @param document [Hash, Array]
        # @param operations [Array<Hash>] RFC 6902 operations (string or symbol keys)
        # @return [Hash, Array] the new document
        # @raise [Error] on an invalid operation
        # @example
        #   JsonPatch.apply({ "a" => 1 }, [{ "op" => "replace", "path" => "/a", "value" => 2 }])
        #   # => { "a" => 2 }
        def apply(document, operations)
          result = deep_copy(document)
          Array(operations).each do |operation|
            op = AGUI.field(operation, "op").to_s
            path = AGUI.field(operation, "path").to_s
            case op
            when "add" then result = add(result, path, deep_copy(AGUI.field(operation, "value")))
            when "remove" then result = remove(result, path)
            when "replace"
              value = deep_copy(AGUI.field(operation, "value"))
              result = path.empty? ? value : add(remove(result, path), path, value)
            when "move"
              from = AGUI.field(operation, "from").to_s
              value = get(result, from)
              result = remove(result, from)
              result = add(result, path, value)
            when "copy" then result = add(result, path, deep_copy(get(result, AGUI.field(operation, "from").to_s)))
            when "test"
              raise Error, "test failed at #{path}" unless get(result, path) == AGUI.field(operation, "value")
            else raise Error, "unknown op #{op.inspect}"
            end
          end
          result
        end

        # Reads the value at a JSON Pointer.
        #
        # @param document [Hash, Array]
        # @param path [String] RFC 6901 pointer ("" is the whole document)
        # @return [Object]
        # @raise [Error] when the path does not resolve
        def get(document, path)
          tokens(path).reduce(document) do |node, token|
            case node
            when Hash then node.key?(token) ? node[token] : raise(Error, "no such path #{path}")
            when Array then node[index_of(node, token, path)] || raise(Error, "no such path #{path}")
            else raise Error, "no such path #{path}"
            end
          end
        end

        # @api private
        def add(document, path, value)
          parts = tokens(path)
          return value if parts.empty?

          parent = get(document, pointer(parts[0...-1]))
          last = parts.last
          case parent
          when Hash then parent[last] = value
          when Array
            if last == "-" then parent << value
            else
              index = Integer(last, exception: false) || raise(Error, "bad index #{last} at #{path}")
              raise Error, "index out of range at #{path}" if index > parent.length || index.negative?

              parent.insert(index, value)
            end
          else raise Error, "cannot add into #{parent.class} at #{path}"
          end
          document
        end

        # @api private
        def remove(document, path)
          parts = tokens(path)
          raise Error, "cannot remove the whole document" if parts.empty?

          parent = get(document, pointer(parts[0...-1]))
          last = parts.last
          case parent
          when Hash then parent.key?(last) ? parent.delete(last) : raise(Error, "no such path #{path}")
          when Array then parent.delete_at(index_of(parent, last, path))
          else raise Error, "cannot remove from #{parent.class} at #{path}"
          end
          document
        end

        # @api private
        def tokens(path)
          return [] if path.nil? || path.empty?
          raise Error, "pointer must start with / (#{path})" unless path.start_with?("/")

          path[1..].split("/", -1).map { |token| token.gsub("~1", "/").gsub("~0", "~") }
        end

        # @api private
        def pointer(parts)
          parts.map { |token| "/#{token.gsub("~", "~0").gsub("/", "~1")}" }.join
        end

        # @api private
        def index_of(array, token, path)
          index = Integer(token, exception: false)
          raise Error, "bad index #{token} at #{path}" if index.nil? || index.negative? || index >= array.length

          index
        end

        # @api private
        def deep_copy(value)
          case value
          when Hash then value.to_h { |key, inner| [key, deep_copy(inner)] }
          when Array then value.map { |inner| deep_copy(inner) }
          else value
          end
        end
      end
    end
  end
end
