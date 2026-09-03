# frozen_string_literal: true

module Poetry
  module Core
    module CSS
      # Herb-AST extraction of the STATIC class attributes in ERB templates:
      # only the literal chunks of a class attribute are collected;
      # ERB-dynamic chunks are skipped entirely, so dynamic class logic can
      # never false-flag. Feeds the Tailwind safelist (template classes
      # survive the host's purge) and doubles as the herb parse gate -
      # parse errors are surfaced, not swallowed.
      #
      # Herb is loaded lazily: it is a build/CI-time tool, not a runtime
      # dependency of the gem.
      #
      # @example
      #   result = Poetry::Core::CSS::TemplateClasses.extract('<div class="p-4 <%= extra %>">')
      #   result.classes # => ["p-4"]
      #
      # @api private
      class TemplateClasses
        ParseError = Struct.new(:path, :message) do
          def to_s
            "#{path}: #{message}"
          end
        end

        Result = Struct.new(:classes, :errors)

        class << self
          # Whether the herb gem is loadable (extraction is optional at
          # install time in a host app; required in poetry's own CI).
          def available?
            herb!
            true
          rescue Poetry::Core::Error
            false
          end

          # Extracts static classes from one ERB source string.
          #
          # @return [Result] classes (Array<String>) + errors (Array<String>)
          def extract(source)
            herb!
            parsed = Herb.parse(source)
            classes = []
            walk(parsed.value) do |node|
              next unless node.is_a?(Herb::AST::HTMLAttributeNode) && class_attribute?(node)

              classes.concat(static_classes(node))
            end
            Result.new(classes.uniq, parsed.errors.map(&:message))
          end

          # Scans every template under root matching the glob.
          #
          # @return [Result] unique sorted classes + per-file ParseErrors
          def scan(root:, glob: "app/components/**/*.html.erb")
            classes = []
            errors = []
            Dir.glob(glob, base: root.to_s).sort.each do |relative|
              result = extract(File.read(File.join(root, relative)))
              classes.concat(result.classes)
              errors.concat(result.errors.map { |message| ParseError.new(relative, message) })
            end
            Result.new(classes.uniq.sort, errors)
          end

          private

          def herb!
            require "herb"
          rescue LoadError
            raise Poetry::Core::Error,
                  "the herb gem is required for template class extraction - add `gem \"herb\"` to your Gemfile"
          end

          def walk(node, &)
            yield node
            node.child_nodes.compact.each { |child| walk(child, &) } if node.respond_to?(:child_nodes)
          end

          def class_attribute?(attribute)
            name = attribute.name.child_nodes.compact.first
            name.respond_to?(:content) && name.content == "class"
          end

          # Only the LiteralNode chunks of the attribute value - ERB chunks
          # are dynamic and deliberately ignored.
          def static_classes(attribute)
            value = attribute.value
            return [] unless value

            value.child_nodes.compact.filter_map do |chunk|
              chunk.content if chunk.is_a?(Herb::AST::LiteralNode)
            end.flat_map(&:split)
          end
        end
      end
    end
  end
end
