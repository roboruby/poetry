# frozen_string_literal: true

require "json"

module Poetry
  module Core
    # poetry check: a static linter for consumer/agent-written ERB.
    # It herb-parses the template and validates every poetry surface against
    # the committed registry + controllers manifest WITHOUT rendering -
    # unknown components/options/variants (did-you-mean), and unknown
    # Stimulus controllers/actions/targets (the Ruby<->JS seam, now at
    # consumer-markup level), plus raw-color classes ('s off-system path,
    # extended from CSS to markup). The mechanical gate an agent self-corrects
    # against before the LLM judge ever runs (eval integration).
    module Check
      SEVERITIES = %i[error warning].freeze

      # A single lint result. file is attached by the Runner; line is
      # 1-based into that file. suggestion is a did-you-mean fix or nil.
      Finding = Struct.new(:rule, :severity, :message, :line, :suggestion, :file, keyword_init: true) do
        def to_h
          { rule: rule, severity: severity, message: message,
            line: line, suggestion: suggestion, file: file }.compact
        end

        def to_s
          location = [file, line].compact.join(":")
          hint = suggestion ? " (did you mean #{suggestion}?)" : ""
          "#{location}: [#{severity}] #{rule}: #{message}#{hint}"
        end
      end

      # Query wrapper over the committed registry hash + the controllers
      # manifest. Language-agnostic data in, poetry semantics out.
      class Catalog
        PASSTHROUGH = %w[class id data aria role style if unless].freeze
        COLOR_FAMILIES = %w[
          slate gray zinc neutral stone red orange amber yellow lime green emerald
          teal cyan sky blue indigo violet purple fuchsia pink rose
        ].freeze
        COLOR_UTILITIES = %w[
          bg text border ring fill stroke from to via outline decoration divide accent caret shadow
        ].freeze
        RAW_COLOR = /\b(?:#{COLOR_UTILITIES.join("|")})-(?:#{COLOR_FAMILIES.join("|")})-\d{2,3}\b/

        def self.from_registry(root, helpers: nil)
          components = YAML.load_file(Pathname.new(root).join(Registry::RELATIVE_PATH), aliases: true)
                           .fetch("components")
          new(components, helpers: helpers)
        end

        # helpers: the FULL set of valid poetry_* helper method names (from
        # the host's ComponentsHelper) - the truth for "is this a real
        # helper". Group / provider / item helpers (poetry_bubble_group,
        # poetry_tooltip_provider) are valid but map to no component, so they
        # pass the existence check and skip option/variant validation. When
        # omitted, the valid set falls back to the component-mapped helpers.
        def initialize(components, helpers: nil)
          @components = components
          # helper name -> registry path: poetry_ + the path under poetry/ui/
          # (poetry/ui/command/dialog -> poetry_command_dialog, avoiding the
          # last-segment collision with poetry/ui/dialog).
          @path_by_helper = components.keys.to_h do |path|
            ["poetry_#{path.delete_prefix("poetry/ui/").tr("/", "_")}", path]
          end
          @helper_names = (helpers&.map(&:to_s) || @path_by_helper.keys).to_set
        end

        def helper_names = @helper_names.to_a

        def helper?(name) = @helper_names.include?(name)
        def path_for(helper) = @path_by_helper[helper]

        def option_names(path)
          entry = @components.fetch(path, {})
          (entry["options"] || []).map { |option| option["name"] } +
            (entry["styles"] || []).map { |style| style["name"] }
        end

        # style name => allowed variant values (only enumerated styles)
        def variants(path)
          styles = @components.dig(path, "styles") || []
          enumerated = styles.reject { |style| (style["variants"] || []).empty? }
          enumerated.to_h { |style| [style["name"], style["variants"]] }
        end

        def raw_color(class_string)
          class_string.scan(RAW_COLOR)
        end
      end

      # Lints one ERB source string. Rules split cleanly: the Ruby-call rules
      # (component/option/variant) walk Prism ASTs of the ERB chunks; the
      # markup rules (wiring/color) walk herb's HTML attribute nodes.
      class Linter
        ACTION_TOKEN = /(?:[\w.:@-]+->)?(?<identifier>poetry--[\w-]+)#(?<method>\w+)/
        POETRY_PREFIX = Stimulus::Manifest::POETRY_PREFIX

        def initialize(catalog)
          @catalog = catalog
        end

        def lint(source)
          require "herb"
          require "prism"
          document = Herb.parse(source)
          findings = document.errors.map do |error|
            Finding.new(rule: "parse-error", severity: :error, message: error.message,
                        line: error.location&.start&.line)
          end
          walk(document.value) do |node|
            findings.concat(ruby_findings(node)) if erb?(node)
            findings.concat(attribute_findings(node)) if node.is_a?(Herb::AST::HTMLAttributeNode)
          end
          findings.sort_by { |finding| [finding.line || 0, finding.rule] }
        end

        private

        def erb?(node)
          node.respond_to?(:content) && node.content.respond_to?(:value) &&
            node.class.name.include?("ERB")
        end

        # --- Ruby-call rules (component / option / variant) ---

        def ruby_findings(node)
          base_line = node.location.start.line
          parsed = Prism.parse(node.content.value)
          calls = []
          collect_calls(parsed.value, calls)
          calls.flat_map { |call| call_findings(call, base_line) }
        end

        def collect_calls(node, into)
          return unless node

          into << node if node.is_a?(Prism::CallNode) && node.name.to_s.start_with?("poetry_")
          node.compact_child_nodes.each { |child| collect_calls(child, into) } if node.respond_to?(:compact_child_nodes)
        end

        def call_findings(call, base_line)
          helper = call.name.to_s
          line = base_line + (call.location.start_line - 1)

          unless @catalog.helper?(helper)
            suggestion = suggest(helper, @catalog.helper_names)
            return [Finding.new(rule: "unknown-component", severity: :error,
                                message: "no poetry component #{helper}", line: line, suggestion: suggestion)]
          end

          # A valid helper with no component mapping (group / provider / item
          # wrapper) - nothing to validate against options/variants.
          path = @catalog.path_for(helper)
          return [] unless path

          keyword_pairs(call).flat_map do |key, value, kw_line|
            option_findings(path, key, value, base_line + kw_line - 1)
          end
        end

        def option_findings(path, key, value, line)
          findings = []
          known = @catalog.option_names(path)
          variants = @catalog.variants(path)

          unless known.include?(key) || Catalog::PASSTHROUGH.include?(key)
            suggestion = suggest(key, known)
            # No suggestion => an intentional pass-through html attribute, not a typo.
            if suggestion
              findings << Finding.new(rule: "unknown-option", severity: :warning,
                                      message: "#{helper_of(path)} has no option #{key}", line: line,
                                      suggestion: suggestion)
            end
          end

          if variants.key?(key) && value && !variants[key].include?(value)
            findings << Finding.new(rule: "unknown-variant", severity: :error,
                                    message: "#{key}: #{value.inspect} is not a #{helper_of(path)} #{key} " \
                                             "(#{variants[key].join(", ")})",
                                    line: line, suggestion: suggest(value, variants[key]))
          end
          findings
        end

        # [key_string, literal_value_or_nil, line] per keyword argument.
        def keyword_pairs(call)
          hash = call.arguments&.arguments&.find { |argument| argument.is_a?(Prism::KeywordHashNode) }
          return [] unless hash

          hash.elements.filter_map do |element|
            next unless element.is_a?(Prism::AssocNode) && element.key.respond_to?(:unescaped)

            [element.key.unescaped, literal_value(element.value), element.key.location.start_line]
          end
        end

        # Simple literal values only (symbols/strings) - dynamic values are
        # unknowable statically and are left alone.
        def literal_value(node)
          node.unescaped if node.is_a?(Prism::SymbolNode) || node.is_a?(Prism::StringNode)
        end

        # --- Markup rules (Stimulus wiring / raw color) ---

        def attribute_findings(node)
          name = attribute_name(node)
          value = attribute_value(node)
          return [] unless name && value

          case name
          when "data-controller" then controller_findings(value, node)
          when "data-action" then action_findings(value, node)
          when "class" then color_findings(value, node)
          when /\Adata-(poetry--[\w-]+)-target\z/ then target_findings(Regexp.last_match(1), value, node)
          else []
          end
        end

        def controller_findings(value, node)
          value.split.filter_map do |identifier|
            next unless identifier.start_with?(POETRY_PREFIX)
            next if definition(identifier)

            Finding.new(rule: "unknown-controller", severity: :error,
                        message: "no poetry controller #{identifier}", line: line_of(node),
                        suggestion: suggest(identifier, Stimulus::Manifest.catalog.keys))
          end
        end

        def action_findings(value, node)
          value.scan(ACTION_TOKEN).filter_map do
            identifier = Regexp.last_match(:identifier)
            method = Regexp.last_match(:method)
            definition = definition(identifier)
            next unless definition
            next if definition["methods"].include?(method)

            Finding.new(rule: "unknown-action", severity: :error,
                        message: "#{identifier} has no action ##{method}", line: line_of(node),
                        suggestion: suggest(method, definition["methods"] - %w[connect disconnect]))
          end
        end

        def target_findings(identifier, value, node)
          definition = definition(identifier)
          return [] unless definition
          return [] if definition["targets"].include?(value)

          [Finding.new(rule: "unknown-target", severity: :error,
                       message: "#{identifier} has no target #{value.inspect}", line: line_of(node),
                       suggestion: suggest(value, definition["targets"]))]
        end

        def color_findings(value, node)
          @catalog.raw_color(value).uniq.map do |match|
            Finding.new(rule: "raw-color", severity: :warning,
                        message: "raw color class #{match.inspect} - use a semantic token " \
                                 "(bg-primary, text-destructive, ...)",
                        line: line_of(node))
          end
        end

        # --- shared ---

        def definition(identifier)
          Stimulus::Manifest.definition(identifier)
        rescue StandardError
          nil # unknown poetry controller is reported by controller_findings
        end

        def suggest(input, dictionary)
          require "did_you_mean"
          DidYouMean::SpellChecker.new(dictionary: dictionary.map(&:to_s)).correct(input.to_s).first
        end

        def helper_of(path) = "poetry_#{path.delete_prefix("poetry/ui/").tr("/", "_")}"
        def line_of(node) = node.location.start.line

        def attribute_name(node)
          name_node = node.name
          return unless name_node

          first = Array(name_node.child_nodes).compact.first
          first.content if first.respond_to?(:content)
        end

        def attribute_value(node)
          value = node.value
          return unless value

          literals = value.child_nodes.compact.filter_map do |chunk|
            chunk.content if chunk.is_a?(Herb::AST::LiteralNode)
          end
          joined = literals.join(" ").strip
          joined.empty? ? nil : joined
        end

        def walk(node, &block)
          return unless node

          yield node
          node.child_nodes.compact.each { |child| walk(child, &block) } if node.respond_to?(:child_nodes)
        end
      end

      # Reads files, lints each, attaches the file to every finding.
      class Runner
        def initialize(catalog)
          @linter = Linter.new(catalog)
        end

        def run(paths)
          paths.flat_map do |path|
            @linter.lint(File.read(path)).each { |finding| finding.file = path }
          end
        end
      end

      module_function

      # Lint file paths against a registry root. Returns [Finding].
      def run(paths:, registry_root:)
        Runner.new(Catalog.from_registry(registry_root)).run(Array(paths))
      end

      # Lint a single source string (no file). Returns [Finding].
      def lint(source, catalog:)
        Linter.new(catalog).lint(source)
      end

      def to_json(findings)
        JSON.pretty_generate(findings.map(&:to_h))
      end

      def to_text(findings)
        return "poetry check: no issues found" if findings.empty?

        errors = findings.count { |finding| finding.severity == :error }
        warnings = findings.length - errors
        (findings.map(&:to_s) + ["", "#{errors} error(s), #{warnings} warning(s)"]).join("\n")
      end
    end
  end
end
