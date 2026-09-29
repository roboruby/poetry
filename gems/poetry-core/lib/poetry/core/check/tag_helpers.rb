# frozen_string_literal: true

module Poetry
  module Core
    module Check
      # The element rule for component templates: an element is built
      # through `element_tag`, and `tag.attributes` takes its hash as an
      # argument.
      #
      # A host may compile its templates with Herb's slots. That compile
      # resolves Action View's own tag helpers into markup ahead of the
      # render, and three shapes do not survive it: attributes handed over
      # in a splat or in a variable are dropped from the element, and a tag
      # name that is not a literal leaves Ruby that does not parse. Nothing
      # reports the first, and the second fails the page. `element_tag` is
      # a helper Herb does not resolve, so the element is built at render
      # time from what the component handed it.
      #
      # WARNING severity, component templates only: a view that hands a tag
      # helper a splat is valid Rails, and whether its host compiles with
      # slots is not something a lint of the source can know.
      #
      # `strict:` is the rule poetry's own templates are held to: no call to
      # `content_tag` or `tag.<name>` at all, whatever its arguments.
      #
      # @api private
      class TagHelpers
        # An ERB tag with code in it: not a comment, not an escaped tag.
        ERB_TAG = /<%(?![#%])(?:==|=|-)?(.*?)-?%>/m

        # A tag-helper linter; it reads the source alone and needs no catalog.
        #
        # @param strict [Boolean] flag every call to an Action View tag
        #   helper, not only the shapes a slot compile gets wrong
        def initialize(strict: false)
          @strict = strict
        end

        # The findings for one ERB source.
        #
        # @param source [String] the template
        # @return [Array<Finding>]
        def lint(source)
          require "prism"

          source.to_enum(:scan, ERB_TAG).flat_map do
            match = Regexp.last_match
            line = source[0...match.begin(1)].count("\n") + 1
            calls_in(Prism.parse(match[1]).value).filter_map { |call| finding_for(call, line) }
          end
        end

        private

        # Every call to `content_tag`, `tag.<name>` or `tag.attributes` under a node.
        def calls_in(node, into = [])
          return into unless node

          into << node if node.is_a?(Prism::CallNode) && tag_helper?(node)
          node.compact_child_nodes.each { |child| calls_in(child, into) } if node.respond_to?(:compact_child_nodes)
          into
        end

        # Whether a call is `content_tag(...)` or a method on the bare `tag` builder.
        def tag_helper?(call)
          return true if call.name == :content_tag && call.receiver.nil?

          builder = call.receiver
          builder.is_a?(Prism::CallNode) && builder.name == :tag && builder.receiver.nil? && builder.arguments.nil?
        end

        # The finding for one call, or nil when the call is one a slot compile reads right.
        def finding_for(call, base_line)
          line = base_line + call.location.start_line - 1
          written = written(call)
          return attributes_finding(call, written, line) if call.name == :attributes && call.receiver

          problem = problem_with(call)
          return unless problem || @strict

          Finding.new(rule: "element-tag", severity: :warning, line: line,
                      message: "#{written} #{problem || "is an Action View tag helper"} - " \
                               "build the element with #{replacement(call)}")
        end

        # The finding for `tag.attributes` handed a splat; its hash as an argument is the form to keep.
        def attributes_finding(call, written, line)
          return unless splat?(call)

          Finding.new(rule: "element-tag", severity: :warning, line: line,
                      message: "#{written} hands its hash over as a splat, which a host compiling with " \
                               "Herb's slots drops from the element - pass it as an argument: " \
                               "tag.attributes(#{splat_source(call)})")
        end

        # What a slot compile gets wrong about a call, in words, or nil.
        def problem_with(call)
          if call.name == :content_tag && !literal_name?(call)
            "takes its tag name from a variable, which stops the template compiling in a host " \
              "that compiles with Herb's slots"
          elsif splat?(call) || variable_options?(call)
            "takes attributes a host compiling with Herb's slots cannot read, and drops them from the element"
          end
        end

        # Whether `content_tag` names its tag with a symbol or a string literal.
        def literal_name?(call)
          first = positional(call).first

          first.is_a?(Prism::SymbolNode) || first.is_a?(Prism::StringNode)
        end

        # Whether a call hands over a double splat.
        def splat?(call)
          keywords(call).any?(Prism::AssocSplatNode)
        end

        # Whether a block call takes its attributes as a variable: with a
        # block, the argument after the tag name is the options.
        def variable_options?(call)
          return false unless call.block

          options = call.name == :content_tag ? positional(call)[1] : positional(call)[0]
          !options.nil? && !options.is_a?(Prism::HashNode)
        end

        # The arguments that are not keywords.
        def positional(call)
          (call.arguments&.arguments || []).grep_v(Prism::KeywordHashNode)
        end

        # The elements of the keyword hash, splats among them.
        def keywords(call)
          (call.arguments&.arguments || []).grep(Prism::KeywordHashNode).flat_map(&:elements)
        end

        # The call as it is written, up to its arguments.
        def written(call)
          call.receiver ? "tag.#{call.name}" : "content_tag"
        end

        # The `element_tag` call to write instead.
        def replacement(call)
          return "element_tag(:#{call.name}, ...)" if call.receiver

          "element_tag(#{positional(call).first&.slice || ":name"}, ...)"
        end

        # The expression a splat spreads.
        def splat_source(call)
          keywords(call).grep(Prism::AssocSplatNode).first&.value&.slice || "attributes"
        end
      end
    end
  end
end
