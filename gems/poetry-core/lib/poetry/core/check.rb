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

        def self.from_registry(root, helpers: nil, icon_names: nil)
          payload = YAML.load_file(Pathname.new(root).join(Registry::RELATIVE_PATH), aliases: true)
          new(payload.fetch("components"), helpers: helpers,
                                           helper_entries: payload["helpers"], icon_names: icon_names)
        end

        # helpers: the FULL set of valid poetry_* helper method names (from
        # the host's ComponentsHelper) - the truth for "is this a real
        # helper". Group / provider / item helpers (poetry_bubble_group,
        # poetry_tooltip_provider) are valid but map to no component, so they
        # pass the existence check and skip option/variant validation. When
        # omitted, the valid set falls back to the component-mapped helpers
        # plus the registry's own "helpers" section (helper_entries), which
        # also carries the value contracts runtime-enforced inside wrapper
        # helpers (poetry_input_group_addon align: et al). icon_names: the
        # active icon set's valid names - when given, icon-formatted option
        # values are checked for membership, not just shape.
        def initialize(components, helpers: nil, helper_entries: nil, icon_names: nil)
          @components = components
          @helper_entries = helper_entries || {}
          @icon_names = icon_names&.to_set(&:to_s)
          # helper name -> registry path: poetry_ + the path under poetry/ui/
          # (poetry/ui/command/dialog -> poetry_command_dialog, avoiding the
          # last-segment collision with poetry/ui/dialog).
          @path_by_helper = components.keys.to_h do |path|
            ["poetry_#{path.delete_prefix("poetry/ui/").tr("/", "_")}", path]
          end
          @helper_names = ((helpers&.map(&:to_s) || @path_by_helper.keys) + @helper_entries.keys).to_set
        end

        attr_reader :icon_names

        def helper_names = @helper_names.to_a

        def helper?(name) = @helper_names.include?(name)
        def path_for(helper) = @path_by_helper[helper]

        def option_names(path)
          entry = @components.fetch(path, {})
          (entry["options"] || []).map { |option| option["name"] } +
            (entry["styles"] || []).map { |style| style["name"] }
        end

        # The full declaration (variants/required/default/format) for one
        # option or style attribute, or nil for pass-through keys.
        def option_entry(path, key)
          entry = @components.fetch(path, {})
          ((entry["options"] || []) + (entry["styles"] || [])).find { |option| option["name"] == key }
        end

        # Options a call cannot omit: required with no default to fall back
        # on (poetry_icon name:). Required styles WITH defaults (alert
        # variant:) are satisfiable by omission and stay out.
        def required_options(path)
          entry = @components.fetch(path, {})
          ((entry["options"] || []) + (entry["styles"] || []))
            .select { |option| option["required"] && !option.key?("default") }
            .map { |option| option["name"] }
        end

        # Slot queries take an OWNER: a component path (String) or a nested
        # builder surface (Hash - the "builders" payload of a slot entry,
        #), so `menubar.with_menu do |menu|` and `menu.with_item` walk
        # the same rules at every depth.
        def slots_of(owner)
          owner.is_a?(Hash) ? (owner["slots"] || []) : (@components.dig(owner, "slots") || [])
        end

        def slot_extras_of(owner)
          owner.is_a?(Hash) ? (owner["slot_extras"] || []) : (@components.dig(owner, "slot_extras") || [])
        end

        # The slot behind a with_<name> call: exact match, the singular form
        # of a many-slot (renders_many :items => with_item), or one of a
        # polymorphic slot's types (with_separator => items' separator type).
        def slot_entry(owner, name)
          slots_of(owner).find do |slot|
            slot["name"] == name || (slot["many"] && slot["name"] == "#{name}s") ||
              (slot["types"] || []).include?(name)
          end
        end

        # Hand-rolled with_* conveniences the registry knows are real
        # (NavigationMenu#with_link) - valid calls with no slot entry to
        # validate against.
        def slot_extra?(owner, name)
          slot_extras_of(owner).include?(name)
        end

        # Every name valid after with_ on this owner (many-slots accept both
        # the plural and the singular setter; polymorphic slots accept one
        # setter per type).
        def slot_call_names(owner)
          slots_of(owner).flat_map do |slot|
            names = slot["many"] ? [slot["name"], slot["name"].delete_suffix("s")] : [slot["name"]]
            names + (slot["types"] || [])
          end + slot_extras_of(owner)
        end

        # The declared value contract of a wrapper helper's option (from the
        # registry "helpers" section), or nil.
        def helper_option_entry(helper, key)
          (@helper_entries.dig(helper, "options") || []).find { |option| option["name"] == key }
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
        # A literal `nil` argument, distinct from "no literal to check"
        # (dynamic values return plain nil and are left alone).
        NIL_LITERAL = Object.new.tap { |sentinel| sentinel.define_singleton_method(:inspect) { "nil" } }.freeze

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
          # Block-param name -> component path, accumulated in document order
          # (the `do |alert|` chunk precedes the `alert.with_icon` chunk), so
          # slot calls resolve across ERB tag boundaries.
          bindings = {}
          walk(document.value) do |node|
            findings.concat(ruby_findings(node, bindings)) if erb?(node)
            findings.concat(attribute_findings(node)) if node.is_a?(Herb::AST::HTMLAttributeNode)
          end
          findings.sort_by { |finding| [finding.line || 0, finding.rule] }
        end

        private

        def erb?(node)
          node.respond_to?(:content) && node.content.respond_to?(:value) &&
            node.class.name.include?("ERB")
        end

        # --- Ruby-call rules (component / option / variant / value / slot) ---

        def ruby_findings(node, bindings)
          base_line = node.location.start.line
          parsed = Prism.parse(node.content.value)
          calls = []
          collect_calls(parsed.value, calls)
          findings = calls.flat_map { |call| call_findings(call, base_line, bindings) }
          findings + slot_findings(parsed.value, bindings, base_line)
        end

        def collect_calls(node, into)
          return unless node

          into << node if node.is_a?(Prism::CallNode) && node.name.to_s.start_with?("poetry_")
          node.compact_child_nodes.each { |child| collect_calls(child, into) } if node.respond_to?(:compact_child_nodes)
        end

        def call_findings(call, base_line, bindings)
          helper = call.name.to_s
          line = base_line + (call.location.start_line - 1)

          unless @catalog.helper?(helper)
            suggestion = suggest(helper, @catalog.helper_names)
            return [Finding.new(rule: "unknown-component", severity: :error,
                                message: "no poetry component #{helper}", line: line, suggestion: suggestion)]
          end

          # A valid helper with no component mapping (group / provider / item
          # wrapper): its registry-declared value contracts still check, and
          # NO wrapper yields anything to its block (a roster invariant) - a
          # declared block param will be nil at render (the W2r app_shell
          # crash: `poetry_sidebar_group do |group|`).
          path = @catalog.path_for(helper)
          return helper_findings(helper, call, base_line) + yieldless_findings(helper, call, line) unless path

          record_binding(call, path, bindings)
          pairs = keyword_pairs(call)
          findings = pairs.flat_map do |key, value, kw_line|
            option_findings(path, key, value, base_line + kw_line - 1)
          end
          findings + missing_option_findings(path, helper_of(path), call, pairs, line)
        end

        def yieldless_findings(helper, call, line)
          block = call.block
          return [] unless block.respond_to?(:parameters) && block.parameters

          [Finding.new(rule: "yieldless-block", severity: :error,
                       message: "#{helper} yields nothing to its block - the param will be nil; " \
                                "remove it and write the content directly", line: line)]
        end

        def option_findings(path, key, value, line)
          findings = []
          known = @catalog.option_names(path)
          entry = @catalog.option_entry(path, key)

          unless known.include?(key) || Catalog::PASSTHROUGH.include?(key)
            suggestion = suggest(key, known)
            # No suggestion => an intentional pass-through html attribute, not a typo.
            if suggestion
              findings << Finding.new(rule: "unknown-option", severity: :warning,
                                      message: "#{helper_of(path)} has no option #{key}", line: line,
                                      suggestion: suggestion)
            end
          end

          findings + (entry ? value_findings(entry, helper_of(path), key, value, line) : [])
        end

        # The value-contract tier (the W2 crash classes poetry check was
        # blind to): enumerated values on any declared attribute, literal nil
        # against required options, and icon-name format/membership.
        def value_findings(entry, owner, key, value, line)
          if value.equal?(NIL_LITERAL)
            return [] unless entry["required"]

            return [Finding.new(rule: "missing-option", severity: :error,
                                message: "#{key}: is required on #{owner} and cannot be nil", line: line)]
          end
          return [] unless value

          variants = entry["variants"]
          if variants && !variants.include?(value)
            return [Finding.new(rule: "unknown-variant", severity: :error,
                                message: "#{key}: #{value.inspect} is not a #{owner} #{key} " \
                                         "(#{variants.join(", ")})",
                                line: line, suggestion: suggest(value, variants))]
          end

          entry["format"] == "icon-name" ? icon_findings(key, value, line) : []
        end

        # Icon names are kebab-case names from the active icon set. Shape is
        # always checkable (the W2 :folder_plus crash); membership only when
        # the catalog carries the set's names.
        def icon_findings(key, value, line)
          unless value.match?(Icons::FileSet::NAME_FORMAT)
            kebab = value.tr("_", "-")
            suggestion = kebab if kebab.match?(Icons::FileSet::NAME_FORMAT) &&
                                  (@catalog.icon_names.nil? || @catalog.icon_names.include?(kebab))
            return [Finding.new(rule: "unknown-icon", severity: :error,
                                message: "#{key}: #{value.inspect} is not an icon name " \
                                         "(icon names are kebab-case, like :\"circle-alert\")",
                                line: line, suggestion: suggestion)]
          end
          return [] if @catalog.icon_names.nil? || @catalog.icon_names.include?(value)

          [Finding.new(rule: "unknown-icon", severity: :error,
                       message: "#{key}: #{value.inspect} is not in the icon set", line: line,
                       suggestion: suggest(value, @catalog.icon_names))]
        end

        # Required-with-no-default options that a literal call omits (a
        # **splat may carry anything - such calls are left alone).
        def missing_option_findings(path, owner, call, pairs, line)
          return [] if splatted?(call)

          (@catalog.required_options(path) - pairs.map(&:first)).map do |key|
            Finding.new(rule: "missing-option", severity: :error,
                        message: "#{key}: is required on #{owner}", line: line)
          end
        end

        # A wrapper helper (no component mapping) with registry-declared
        # value contracts: poetry_input_group_addon(align: :leading) fails
        # here the way it fails at render - minus the render.
        def helper_findings(helper, call, base_line)
          keyword_pairs(call).flat_map do |key, value, kw_line|
            entry = @catalog.helper_option_entry(helper, key)
            entry ? value_findings(entry, helper, key, value, base_line + kw_line - 1) : []
          end
        end

        # --- slot rules (typed slots are prop calls, not blocks) ---

        # A poetry_* call opening a block binds its param name to the
        # component (poetry_alert do |alert| -> alert), so later chunks can
        # validate alert.with_icon(...) against the alert slot surface.
        # Bindings map param name -> [owner, label]: owner is a component
        # path or a nested builder surface, label names the owner in
        # messages.
        def record_binding(call, path, bindings)
          name = block_param_name(call)
          bindings[name] = [path, helper_of(path)] if name
        end

        def block_param_name(call)
          block_parameters = call.block&.parameters&.parameters
          name = block_parameters && block_parameters.requireds.first&.name
          name&.to_s
        rescue StandardError
          nil # a block shape Prism could not recover fully never blocks linting
        end

        def slot_findings(root, bindings, base_line)
          slot_calls = []
          collect_slot_calls(root, slot_calls)
          slot_calls.flat_map do |call|
            owner, label = bindings[receiver_name(call)]
            owner ? slot_call_findings(call, owner, label, base_line, bindings) : []
          end
        end

        def collect_slot_calls(node, into)
          return unless node

          into << node if node.is_a?(Prism::CallNode) && node.name.to_s.start_with?("with_") && node.receiver
          return unless node.respond_to?(:compact_child_nodes)

          node.compact_child_nodes.each do |child|
            collect_slot_calls(child, into)
          end
        end

        # Inside one ERB chunk the receiver parses as a local variable; in a
        # later chunk the same name parses as a bare method call - both are
        # the block param the bindings map knows.
        def receiver_name(call)
          receiver = call.receiver
          case receiver
          when Prism::LocalVariableReadNode then receiver.name.to_s
          when Prism::CallNode then receiver.name.to_s if receiver.receiver.nil? && receiver.arguments.nil?
          end
        end

        def slot_call_findings(call, owner, label, base_line, bindings)
          slot_name = call.name.to_s.delete_prefix("with_")
          line = base_line + (call.location.start_line - 1)
          entry = @catalog.slot_entry(owner, slot_name)
          unless entry
            return [] if @catalog.slot_extra?(owner, slot_name)

            return [Finding.new(rule: "unknown-slot", severity: :error,
                                message: "#{label} has no slot #{slot_name}", line: line,
                                suggestion: suggest(slot_name, @catalog.slot_call_names(owner)))]
          end

          # A setter opening a block over a declared builder binds the
          # nested surface (menubar.with_menu do |menu| - menu's own items
          # then lint at this same depth).
          if (surface = entry.dig("builders", slot_name)) && (param = block_param_name(call))
            bindings[param] = [surface, "with_#{slot_name}"]
          end

          findings = arity_findings(entry, slot_name, call, line)
          component = entry["component"]
          return findings unless component

          # A typed slot IS a component call: same option/value rules, plus
          # the block-form trap (with_icon do ... end builds the component
          # with no props - the W2 alert crash).
          pairs = keyword_pairs(call)
          findings += pairs.flat_map do |key, value, kw_line|
            option_findings(component, key, value, base_line + kw_line - 1)
          end
          unless splatted?(call)
            findings += (@catalog.required_options(component) - pairs.map(&:first)).map do |key|
              Finding.new(rule: "missing-option", severity: :error,
                          message: "#{slot_name} is a typed slot rendering #{helper_of(component)} - pass " \
                                   "#{key}: (with_#{slot_name}(#{key}: ...)), not a block", line: line)
            end
          end
          findings
        end

        # Positional args a setter does not take (the W2r menu crash:
        # `with_item(:item, ...)` guessed a type-as-argument dispatch no
        # setter has - the type IS the setter). Arity comes from the
        # registry's introspected lambda signatures; anything unknowable
        # (splats, untracked setters) is left alone.
        def arity_findings(entry, slot_name, call, line)
          max = entry.dig("setter_args", slot_name)
          return [] unless max

          positionals = positional_arguments(call)
          return [] if positionals.nil? || positionals.size <= max

          first = positionals.first
          first_symbol = first.unescaped if first.is_a?(Prism::SymbolNode)
          sibling = first_symbol && first_symbol != slot_name &&
                    (entry["setter_args"].key?(first_symbol) || (entry["types"] || []).include?(first_symbol))
          detail = if first_symbol && (entry["types"] || []).include?(first_symbol)
                     " - the type is the setter (#{(entry["types"] || []).map { |type| "with_#{type}" }.join(" / ")})"
                   else
                     ""
                   end
          limit = max.zero? ? "keyword options only" : "at most #{max} positional argument#{"s" if max > 1}"
          [Finding.new(rule: "slot-arity", severity: :error,
                       message: "with_#{slot_name} takes #{limit}#{detail}", line: line,
                       suggestion: (sibling ? "with_#{first_symbol}" : nil))]
        end

        # nil when a splat makes the count unknowable.
        def positional_arguments(call)
          arguments = call.arguments&.arguments
          return [] unless arguments
          return nil if arguments.any?(Prism::SplatNode)

          arguments.reject do |argument|
            argument.is_a?(Prism::KeywordHashNode) || argument.is_a?(Prism::BlockArgumentNode)
          end
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

        # A call carrying **splat (or a bare hash variable) may set anything
        # statically invisible - required-option checks stand down.
        def splatted?(call)
          arguments = call.arguments&.arguments
          return false unless arguments

          arguments.any? do |argument|
            argument.is_a?(Prism::KeywordHashNode) &&
              argument.elements.any? { |element| !element.is_a?(Prism::AssocNode) }
          end
        end

        # Simple literal values only (symbols/strings, plus literal nil as
        # its own sentinel) - dynamic values are unknowable statically and
        # are left alone.
        def literal_value(node)
          return NIL_LITERAL if node.is_a?(Prism::NilNode)

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
