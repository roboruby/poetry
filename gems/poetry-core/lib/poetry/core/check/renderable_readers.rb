# frozen_string_literal: true

module Poetry
  module Core
    module Check
      # The renderable rule for a component class: no declaration defines
      # the reader Rails asks a component for.
      #
      # Rails reads `format` off what it renders and takes the answer for
      # the format of the template. An `option :format`, a `style :format`
      # or a slot named `format` defines that reader, and it answers with
      # the declared value. A render through the renderer then raises
      # `Invalid formats`. A render from a controller has always gone
      # through it; from Rails 8.2 a render in a view goes through it too,
      # which is every helper call on the page.
      #
      # A class that answers Rails itself is left alone: one that defines
      # `format` in its own body, with `def` or `define_method`, keeps the
      # keyword for its callers and reads the value under another name.
      #
      # @api private
      class RenderableReaders
        # The rule the findings carry.
        RULE = "renderable-reader"

        # The name Rails reads off a renderable.
        READER = "format"

        # The declarations that define a reader named after the declaration.
        DECLARATIONS = %w[option style renders_one renders_many].freeze

        # A rule over a Ruby file; it reads the source alone and needs no
        # catalog.
        #
        # @param severity [Symbol] :warning, or :error where the host's
        #   Rails renders a view through the renderer
        def initialize(severity: :warning)
          @severity = severity
        end

        # The findings for one Ruby source.
        #
        # @param source [String] the Ruby source
        # @return [Array<Finding>]
        def lint(source)
          require "prism"

          result = Prism.parse(source)
          return [] unless result.success?

          findings = []
          walk(result.value, findings)
          findings
        end

        private

        # Judges every class body on the way down.
        def walk(node, findings)
          findings.concat(class_findings(node)) if node.is_a?(Prism::ClassNode)
          node.compact_child_nodes.each { |child| walk(child, findings) }
        end

        # The declarations in one class body that define the reader, unless
        # the body defines it itself.
        def class_findings(klass)
          statements = klass.body.is_a?(Prism::StatementsNode) ? klass.body.body : []
          return [] if statements.any? { |statement| answers_rails?(statement) }

          statements.filter_map do |statement|
            next unless (name = declaration(statement))

            Finding.new(rule: RULE, severity: @severity, line: statement.location.start_line,
                        message: message(name))
          end
        end

        # A `def format` or `define_method(:format)` in the class body.
        def answers_rails?(statement)
          return statement.name.to_s == READER if statement.is_a?(Prism::DefNode)

          call?(statement, "define_method") && literal_name(statement.arguments&.arguments&.first) == READER
        end

        # The declaration keyword when the statement declares the reader.
        def declaration(statement)
          return unless statement.is_a?(Prism::CallNode) && statement.receiver.nil?

          name = statement.name.to_s
          return unless DECLARATIONS.include?(name)
          return unless literal_name(statement.arguments&.arguments&.first) == READER

          name
        end

        # A receiverless call by that name.
        def call?(node, name)
          node.is_a?(Prism::CallNode) && node.receiver.nil? && node.name.to_s == name
        end

        # A symbol or string literal's text, or nil.
        def literal_name(node)
          node.unescaped if node.is_a?(Prism::SymbolNode) || node.is_a?(Prism::StringNode)
        end

        # The finding's sentence.
        def message(name)
          "#{name} :#{READER} defines the reader Rails asks a component for the format of its template, and it " \
            "answers with the declared value: a render through the renderer raises `Invalid formats`, and from " \
            "Rails 8.2 every render in a view goes through it - keep the keyword and read the value under another " \
            "name, with `define_method(:#{READER}) { nil }` beside the declaration, or rename it"
        end
      end
    end
  end
end
