# frozen_string_literal: true

module Poetry
  module Core
    # The namespaces a gem hides from its reference with `@api private`,
    # read from source without booting and without YARD. A class or module
    # whose leading docstring carries the tag is internal, and so is
    # everything nested under it; a constant assigned a `Struct.new`,
    # `Data.define`, `Class.new` or `Module.new` counts as a namespace too.
    # The registry writes the list beside the components (its "internals"
    # section) so `poetry check` can tell a host it reached past the
    # documented surface.
    module ApiInternals
      # The docstring line that hides a namespace from the reference.
      TAG = "# @api private"

      # The tagged namespaces under a gem root, top-most only (a namespace
      # nested under a tagged one is covered by the prefix), sorted.
      #
      # @param root [String, Pathname] the gem root (app/ and lib/ are read)
      # @return [Array<String>] fully qualified names
      def self.scan(root)
        require "prism"
        paths = Dir.glob(File.join(root.to_s, "{app,lib}", "**", "*.rb")).flat_map do |file|
          result = Prism.parse_file(file)
          next [] unless result.success?

          result.attach_comments!
          visitor = Visitor.new
          result.value.accept(visitor)
          visitor.paths
        end
        paths = paths.uniq.sort
        paths.reject { |path| paths.any? { |other| other != path && path.start_with?("#{other}::") } }
      end

      # Whether a written constant path is one of the internals or sits
      # under one.
      #
      # @param path [String] a fully qualified constant name as written
      # @param internals [Array<String>] the top-most internal namespaces
      # @return [Boolean]
      def self.internal?(path, internals)
        internals.any? { |namespace| path == namespace || path.start_with?("#{namespace}::") }
      end

      # Collects the tagged namespaces of one file, tracking the nesting.
      # @api private
      class Visitor < Prism::Visitor
        # The receivers whose new or define turns a constant into a namespace.
        NAMESPACE_FACTORIES = %w[Struct Data Class Module].freeze

        # The tagged namespaces found so far, in source order.
        attr_reader :paths

        # Starts with an empty nesting and no paths.
        def initialize
          @nesting = []
          @paths = []
          super
        end

        # Tracks the module's name while its body is walked.
        def visit_module_node(node)
          with_namespace(node.constant_path.slice, node) { super }
        end

        # Tracks the class's name while its body is walked.
        def visit_class_node(node)
          with_namespace(node.constant_path.slice, node) { super }
        end

        # Records a tagged constant assigned through a namespace factory.
        def visit_constant_write_node(node)
          value = node.value
          if value.is_a?(Prism::CallNode) && %i[new define].include?(value.name) &&
             value.receiver.respond_to?(:slice) && NAMESPACE_FACTORIES.include?(value.receiver.slice) && tagged?(node)
            @paths << (@nesting + [node.name.to_s]).join("::")
          end
          super
        end

        private

        # Whether the node's leading comments carry the tag.
        def tagged?(node)
          node.location.leading_comments.any? { |comment| comment.slice.strip == TAG }
        end

        # Nests the name for the block, recording the path when the node is tagged.
        def with_namespace(name, node)
          parts = name.split("::")
          @nesting.concat(parts)
          @paths << @nesting.join("::") if tagged?(node)
          yield
        ensure
          parts.size.times { @nesting.pop }
        end
      end
    end
  end
end
