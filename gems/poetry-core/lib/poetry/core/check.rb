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
          from_registries([root], helpers: helpers, icon_names: icon_names)
        end

        # A host catalog spans every installed poetry gem (ui + charts): a
        # gem whose components stay out of the merge leaves its helpers
        # name-valid but pathless, and every one of their blocks reads as a
        # yieldless wrapper block (the chart false positives).
        def self.from_registries(roots, helpers: nil, icon_names: nil)
          payloads = roots.map do |root|
            YAML.load_file(Pathname.new(root).join(Registry::RELATIVE_PATH), aliases: true)
          end
          new(payloads.map { |payload| payload.fetch("components") }.reduce({}, :merge),
              helpers: helpers,
              helper_entries: payloads.map { |payload| payload["helpers"] || {} }.reduce({}, :merge),
              icon_names: icon_names,
              helper_args: payloads.map { |payload| payload["helper_args"] || {} }.reduce({}, :merge))
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
        def initialize(components, helpers: nil, helper_entries: nil, icon_names: nil, helper_args: nil)
          @components = components
          @helper_entries = helper_entries || {}
          @helper_args = helper_args || {}
          @icon_names = icon_names&.to_set(&:to_s)
          # helper name -> registry path: poetry_ + the path under the gem
          # namespace (poetry/ui/command/dialog -> poetry_command_dialog,
          # avoiding the last-segment collision with poetry/ui/dialog). The
          # prefix strip covers every poetry gem, not just poetry/ui/ - a
          # merged catalog carries poetry/charts/* too, and a chart helper
          # that fails to map here reads as a yielding wrapper (the
          # chart yieldless-block false positives).
          @path_by_helper = components.keys.to_h do |path|
            ["poetry_#{path.sub(%r{\Apoetry/[^/]+/}, "").tr("/", "_")}", path]
          end
          @helper_names = ((helpers&.map(&:to_s) || @path_by_helper.keys) + @helper_entries.keys).to_set
        end

        attr_reader :icon_names

        def helper_names = @helper_names.to_a

        def helper?(name) = @helper_names.include?(name)
        def path_for(helper) = @path_by_helper[helper]

        # Max positional arity for a helper, or nil when the registry does
        # not state one (legacy registries stay lint-identical).
        def helper_args(helper) = @helper_args[helper]

        # A pathless helper that DECLARES it yields (registry helpers
        # section, "yields" key): the dispatcher exception to the
        # no-wrapper-yields invariant - poetry_chart routes to a component
        # that yields its slot builder.
        def helper_yields?(helper) = !@helper_entries.dig(helper, "yields").nil?

        # The element-level wiring projection (Phase 5): which elements of
        # a component carry which controllers, values, actions, and
        # targets - use_stimulus declarations, serialized. Empty for
        # registries that predate the projection; future check rules and
        # suggestions read the component's actual wiring here instead of
        # the controllers section's whole-API view.
        def stimulus_wiring(path)
          @components.dig(path, "stimulus") || []
        end

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

        # The component's requires_content hint (Avatar: "the initials
        # fallback"), or nil when content is optional.
        def requires_content(path)
          @components.dig(path, "requires_content")
        end

        # Setters an owner's call cannot omit (the menu crash class:
        # Menubar's menu without with_trigger raises at render) - setter
        # name => hint, at every depth the slot queries work at.
        def required_slots(owner)
          (owner.is_a?(Hash) ? owner["required_slots"] : @components.dig(owner, "required_slots")) || {}
        end

        # The conditional any-of contracts: groups of alternatives
        # (content / slots / options) of which a call must satisfy at least
        # one - Button's visible-content rule, Command's accessible name.
        def requires_any(path)
          @components.dig(path, "requires_any") || []
        end

        # The setter names that satisfy one required-slot key: the slot's
        # own name, a collection's singular, and every polymorphic type
        # ("at least one item" is satisfied by any member of the union -
        # exactly the runtime items? predicate).
        def satisfying_setters(owner, key)
          slot = slot_entry(owner, key)
          return [key] unless slot

          names = [slot["name"]]
          names << slot["name"].delete_suffix("s") if slot["many"]
          names + (slot["types"] || [])
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
          # Every block-param binding this lint opens, in document order -
          # each accumulates the setters actually called on it so the
          # required-slot accounting can run once the whole template has
          # been walked (a with_trigger in the last chunk satisfies a
          # requirement opened in the first). Reset per lint: the Runner
          # reuses one Linter across files.
          @instances = []
          document = Herb.parse(source)
          findings = document.errors.map do |error|
            Finding.new(rule: "parse-error", severity: :error, message: error.message,
                        line: error.location&.start&.line)
          end
          # Block-param name -> instance (owner + accounting), accumulated in
          # document order (the `do |alert|` chunk precedes the
          # `alert.with_icon` chunk), so slot calls resolve across ERB tag
          # boundaries.
          bindings = {}
          walk(document.value) do |node|
            findings.concat(ruby_findings(node, bindings)) if erb?(node)
            findings.concat(attribute_findings(node)) if node.is_a?(Herb::AST::HTMLAttributeNode)
          end
          findings.concat(missing_slot_findings)
          findings.sort_by { |finding| [finding.line || 0, finding.rule] }
        end

        private

        def erb?(node)
          node.respond_to?(:content) && node.content.respond_to?(:value) &&
            node.class.name.include?("ERB") && !erb_comment?(node)
        end

        # <%# ... %> parses as an ERBContentNode like any output tag - only
        # the tag opening tells prose from code. Comment text mentioning a
        # helper ("a plain poetry_input chromes it") must never reach Prism
        # as Ruby (the helper-arity false positives).
        def erb_comment?(node)
          node.respond_to?(:tag_opening) && node.tag_opening&.value == "<%#"
        end

        # --- Ruby-call rules (component / option / variant / value / slot) ---

        def ruby_findings(node, bindings)
          base_line = node.location.start.line
          parsed = Prism.parse(node.content.value)
          calls = []
          collect_calls(parsed.value, calls)
          content_fed = content_fed_calls(parsed.value)
          findings = calls.flat_map { |call| call_findings(call, base_line, bindings, content_fed) }
          findings += slot_findings(parsed.value, bindings, base_line)
          mark_escaped_bindings(parsed.value, bindings)
          findings
        end

        # Receivers of a chained .with_content("...") - content arrives
        # without a block, so the missing-content-block rule stands down.
        def content_fed_calls(node, into = Set.new)
          return into unless node

          into << node.receiver if node.is_a?(Prism::CallNode) && node.name == :with_content && node.receiver
          if node.respond_to?(:compact_child_nodes)
            node.compact_child_nodes.each do |child|
              content_fed_calls(child, into)
            end
          end
          into
        end

        def collect_calls(node, into)
          return unless node

          into << node if node.is_a?(Prism::CallNode) && node.name.to_s.start_with?("poetry_")
          node.compact_child_nodes.each { |child| collect_calls(child, into) } if node.respond_to?(:compact_child_nodes)
        end

        def call_findings(call, base_line, bindings, content_fed = Set.new)
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
          unless path
            return helper_findings(helper, call, base_line) + yieldless_findings(helper, call, line) +
                   helper_arity_findings(helper, call, line)
          end

          record_binding(call, path, bindings, line)
          pairs = keyword_pairs(call)
          findings = pairs.flat_map do |key, value, kw_line|
            option_findings(path, key, value, base_line + kw_line - 1)
          end
          findings + missing_option_findings(path, helper_of(path), call, pairs, line) +
            helper_arity_findings(helper, call, line) +
            content_findings(path, helper, call, line, content_fed) +
            blockless_slot_findings(path, helper, call, pairs, line) +
            requires_any_findings(path, call, pairs, line, content_fed)
        end

        # The requires_content tier (the floating crash class): a
        # component that raises without a content block, called with none.
        # Positional arguments or a chained .with_content may carry content
        # invisibly - such calls are left alone.
        def content_findings(path, helper, call, line, content_fed)
          hint = @catalog.requires_content(path)
          return [] unless hint
          return [] if call.block || content_fed.include?(call)

          positionals = positional_arguments(call)
          return [] if positionals.nil? || positionals.any?

          [Finding.new(rule: "missing-content-block", severity: :error,
                       message: "#{helper} requires a content block (#{hint})", line: line)]
        end

        # The helper-arity rule (the blocks-gate site_nav crash class:
        # `poetry_link "text", href:` on a kwargs-only helper). Enforced
        # only where the registry states an arity - introspected from the
        # helper module's real signatures, never assumed - and only on
        # receiverless calls (a form builder's poetry_select owns its own
        # signature).
        def helper_arity_findings(helper, call, line)
          return [] if call.receiver

          allowed = @catalog.helper_args(helper)
          return [] unless allowed

          positionals = positional_arguments(call)
          return [] if positionals.nil? || positionals.size <= allowed

          limit = if allowed.zero?
                    "no positional arguments - options are keywords, content is the block"
                  else
                    "at most #{allowed} positional argument#{"s" if allowed > 1}"
                  end
          [Finding.new(rule: "helper-arity", severity: :error,
                       message: "#{helper} takes #{limit}", line: line)]
        end

        def yieldless_findings(helper, call, line)
          return [] if @catalog.helper_yields?(helper)

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

          # Icons.suggest, not the generic checker: it catches the Lucide v1
          # reversed-compound renames (alert-circle -> circle-alert) that
          # edit distance misses every time.
          [Finding.new(rule: "unknown-icon", severity: :error,
                       message: "#{key}: #{value.inspect} is not in the icon set", line: line,
                       suggestion: Icons.suggest(value, @catalog.icon_names))]
        end

        # Required-with-no-default options that a literal call omits (a
        # **splat may carry anything - such calls are left alone).
        def missing_option_findings(path, owner, call, pairs, line)
          # A receiver'd call owns its contract (a form builder's
          # poetry_date_picker supplies name: itself) - same stand-down as
          # helper arity.
          return [] if splatted?(call) || call.receiver

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
        # Bindings map param name -> instance: owner is a component path or
        # a nested builder surface, label names the owner in
        # messages, and called/escaped carry the required-slot accounting.
        def record_binding(call, path, bindings, line)
          name = block_param_name(call)
          bindings[name] = track_instance(owner: path, label: helper_of(path), line: line) if name
        end

        def track_instance(owner:, label:, line:)
          instance = { owner: owner, label: label, line: line, called: Set.new, escaped: false }
          @instances << instance
          instance
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
            instance = bindings[receiver_name(call)]
            instance ? slot_call_findings(call, instance, base_line, bindings) : []
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

        def slot_call_findings(call, instance, base_line, bindings)
          owner = instance[:owner]
          label = instance[:label]
          slot_name = call.name.to_s.delete_prefix("with_")
          instance[:called] << slot_name
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
            bindings[param] = track_instance(owner: surface, label: "with_#{slot_name}", line: line)
          end

          findings = arity_findings(entry, slot_name, call, line) +
                     setter_block_findings(entry, slot_name, call, line) +
                     setter_keyword_findings(entry, slot_name, call, base_line)
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
          if (hint = @catalog.requires_content(component)) && call.block.nil?
            findings << Finding.new(rule: "missing-content-block", severity: :error,
                                    message: "with_#{slot_name} renders #{helper_of(component)}, which " \
                                             "requires a content block (#{hint})", line: line)
          end
          # The any-of contracts ride the component fact too (: the
          # toast crash was with_action(label:) - a Button through a
          # forwarding lambda, nothing visible). At a slot site the block
          # IS the content; sub-slot alternatives are unreachable and drop
          # out of the satisfiable set.
          unless splatted?(call) || positional_arguments(call).nil? || positional_arguments(call).any?
            keys = pairs.map(&:first)
            @catalog.requires_any(component).each do |group|
              next if call.block && group["content"]
              next if (group["options"] || []).intersect?(keys)

              # Sub-slot alternatives are unreachable through a slot call -
              # the phrase names only what THIS site can still do.
              reachable = group.slice("hint", "content", "options")
              reachable = group unless reachable["content"] || reachable["options"]
              findings << Finding.new(rule: "requires-any", severity: :error,
                                      message: "with_#{slot_name} renders #{helper_of(component)}, which " \
                                               "requires #{any_of_phrase(reachable)}", line: line)
            end
          end
          findings
        end

        # --- the required-slot tier (the menu crash class) ---

        # A required-slot component called with NO block cannot set the
        # slot at all (the setters live on the block param) - the blockless
        # sibling of the bound-block accounting below. Positional arguments
        # or a same-named keyword may carry the requirement invisibly, and
        # a receiver'd call (a form builder's poetry_select) owns its own
        # contract - all of those stand down.
        def blockless_slot_findings(path, helper, call, pairs, line)
          return [] if call.block || call.receiver

          required = @catalog.required_slots(path)
          return [] if required.empty?

          positionals = positional_arguments(call)
          return [] if positionals.nil? || positionals.any? || splatted?(call)

          keys = pairs.map(&:first)
          required.filter_map do |key, hint|
            next if keys.include?(key)

            Finding.new(rule: "missing-slot", severity: :error,
                        message: "#{helper} requires with_#{key} (#{hint}) - open a block: " \
                                 "#{helper}(...) do |c| ... c.with_#{key} ... end", line: line)
          end
        end

        # The conditional any-of tier (: the two crash classes that
        # survived every single-fact tier). A group passes when ANY listed
        # alternative is satisfied or possibly satisfied: a block counts
        # for content AND for slot alternatives (the setters may be called
        # inside), a listed option key counts by presence (a literal-false
        # loading: is the runtime's to catch), and receiver'd calls,
        # splats, and positionals stand the whole rule down.
        def requires_any_findings(path, call, pairs, line, content_fed)
          groups = @catalog.requires_any(path)
          return [] if groups.empty? || call.receiver || splatted?(call)

          positionals = positional_arguments(call)
          return [] if positionals.nil? || positionals.any?

          keys = pairs.map(&:first)
          groups.filter_map do |group|
            next if call.block && (group["content"] || (group["slots"] || []).any?)
            next if content_fed.include?(call) && group["content"]
            next if (group["options"] || []).intersect?(keys)

            Finding.new(rule: "requires-any", severity: :error,
                        message: "#{helper_of(path)} requires #{any_of_phrase(group)}", line: line)
          end
        end

        def any_of_phrase(group)
          parts = []
          parts << "a content block" if group["content"]
          parts.concat((group["slots"] || []).map { |name| "with_#{name}" })
          parts.concat((group["options"] || []).map { |key| "#{key}:" })
          "one of #{parts.join(" / ")} (#{group["hint"]})"
        end

        # A bound block param that travels anywhere except a with_* receiver
        # position (a partial's locals, a helper argument, a non-setter
        # method) may set slots where this lint cannot see - required-slot
        # accounting stands down for that instance rather than guess.
        def mark_escaped_bindings(root, bindings)
          return if bindings.empty?

          receivers = Set.new
          walk_prism(root) do |node|
            next unless node.is_a?(Prism::CallNode) && node.name.to_s.start_with?("with_")

            receivers << node.receiver.object_id if node.receiver
          end
          walk_prism(root) do |node|
            name = variable_read_name(node)
            next unless name && (instance = bindings[name])

            instance[:escaped] = true unless receivers.include?(node.object_id)
          end
        end

        # A read of a bound name: a local variable in the binding chunk, a
        # bare argless call in later chunks (the receiver_name duality).
        def variable_read_name(node)
          case node
          when Prism::LocalVariableReadNode then node.name.to_s
          when Prism::CallNode
            node.name.to_s if node.receiver.nil? && node.arguments.nil? && node.block.nil?
          end
        end

        # The end-of-template accounting: every non-escaped binding must
        # have called each required setter of its owner (satisfied by the
        # slot's own setter, a collection's singular, or any polymorphic
        # type - the runtime predicate, textually). The menu arm ran
        # FOUR truthful checks and crashed on exactly this omission.
        def missing_slot_findings
          @instances.flat_map do |instance|
            next [] if instance[:escaped]

            @catalog.required_slots(instance[:owner]).filter_map do |key, hint|
              next if @catalog.satisfying_setters(instance[:owner], key).intersect?(instance[:called].to_a)

              Finding.new(rule: "missing-slot", severity: :error,
                          message: "#{instance[:label]} requires with_#{key} (#{hint})",
                          line: instance[:line])
            end
          end
        end

        def walk_prism(node, &block)
          return unless node

          yield node
          return unless node.respond_to?(:compact_child_nodes)

          node.compact_child_nodes.each { |child| walk_prism(child, &block) }
        end

        # The block seam of a setter, both directions. A yieldless
        # setter (its lambda consumes the block as content) yields nothing -
        # a declared block param is nil at render (the menu crash:
        # `menu.with_item do |item|`). A required_content setter crashes
        # WITHOUT a block (Carousel with_item).
        def setter_block_findings(entry, slot_name, call, line)
          findings = []
          if (entry["yieldless"] || []).include?(slot_name) && block_param_name(call)
            findings << Finding.new(rule: "yieldless-block", severity: :error,
                                    message: "with_#{slot_name} yields nothing to its block - the param " \
                                             "will be nil; remove it and write the content directly",
                                    line: line)
          end
          if (hint = entry.dig("required_content", slot_name)) && call.block.nil?
            findings << Finding.new(rule: "missing-content-block", severity: :error,
                                    message: "with_#{slot_name} requires a content block (#{hint})",
                                    line: line)
          end
          findings
        end

        # Keywords a closed-signature setter does not accept (the
        # artwork_carousel crash: `with_item(class:)` against
        # `|classes: nil, &block|` - an ArgumentError at render, and NOT a
        # pass-through surface, unlike component options).
        def setter_keyword_findings(entry, slot_name, call, base_line)
          allowed = entry.dig("setter_kwargs", slot_name)
          return [] unless allowed

          takes = "takes #{allowed.map { |name| "#{name}:" }.join(", ")}"
          keyword_pairs(call).filter_map do |key, _value, kw_line|
            next if allowed.include?(key)

            Finding.new(rule: "slot-keyword", severity: :error,
                        message: "with_#{slot_name} does not take #{key}: (#{takes})",
                        line: base_line + kw_line - 1, suggestion: suggest(key, allowed))
          end
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

      # The declaration tier (the FLASH_ICONS pattern): icon names
      # that live in app RUBY - `icon:`-keyed hash pairs and ICON-named
      # constants - and reach the renderer through a lookup the ERB tier can
      # never see (`poetry_icon name: ICONS[status]`). Prism-walks .rb files
      # for icon-shaped literals in those declaration positions and validates
      # them against the active set. Warning severity: a key named `icon` is
      # strong-but-not-certain evidence. Skipped entirely when the catalog
      # carries no set names (membership IS the question), and on files that
      # don't parse (broken Ruby is not this tier's finding). Prism ships
      # with Ruby - no new dependency, same optional-parse posture as herb.
      class IconDeclarations
        # `icon:`, `menu_icon:`, `icons:`, `status_icons:` - but NOT
        # `icon_position:` (an enum, not a name; the FP that loose /icon/
        # matching would create).
        ICON_KEY = /\A[a-z0-9_]*icons?\z/
        # ICON underscore-bounded on both sides: FLASH_ICONS, ICON_NAMES,
        # ICON - but not LEXICON or ICONOGRAPHY.
        ICON_CONSTANT = /(?:\A|_)ICONS?(?:_|\z)/
        # A literal that could be an icon name. Excludes CSS class strings
        # (spaces, slashes), paths, and interpolation.
        NAME_SHAPED = /\A[a-z][a-z0-9_-]*\z/

        def initialize(catalog)
          @catalog = catalog
        end

        # Lint one Ruby source string. Returns [Finding].
        def lint(source)
          names = @catalog.icon_names
          return [] if names.nil?

          require "prism"
          result = Prism.parse(source)
          return [] unless result.success?

          findings = []
          walk(result.value, findings, names, Set.new)
          findings
        end

        private

        def walk(node, findings, names, seen)
          case node
          when Prism::AssocNode
            key = node.key
            if key.is_a?(Prism::SymbolNode) && key.unescaped.match?(ICON_KEY)
              harvest(node.value, key.unescaped, findings, names, seen)
            end
          when Prism::ConstantWriteNode
            harvest(node.value, node.name.to_s, findings, names, seen) if node.name.to_s.match?(ICON_CONSTANT)
          end
          node.child_nodes.compact.each { |child| walk(child, findings, names, seen) }
        end

        # Collects icon-name candidates from a declaration value: a bare
        # literal, an array of literals, or a hash's VALUES ({ success:
        # :circle-check } - the keys are the app's domain, not icon names).
        # `.freeze` and parentheses are peeled so frozen constant maps still
        # harvest.
        def harvest(value_node, owner, findings, names, seen)
          value_node = unwrap(value_node)
          case value_node
          when Prism::SymbolNode, Prism::StringNode
            check(value_node, owner, findings, names, seen)
          when Prism::ArrayNode
            value_node.elements.each { |element| harvest(element, owner, findings, names, seen) }
          when Prism::HashNode
            value_node.elements.grep(Prism::AssocNode).each { |assoc| harvest(assoc.value, owner, findings, names, seen) }
          end
        end

        def unwrap(value_node)
          while value_node.is_a?(Prism::CallNode) && value_node.name == :freeze && value_node.receiver &&
                (value_node.arguments.nil? || value_node.arguments.arguments.empty?)
            value_node = value_node.receiver
          end
          value_node = value_node.body.first if value_node.is_a?(Prism::ParenthesesNode) &&
                                                value_node.body.is_a?(Prism::StatementsNode) &&
                                                value_node.body.body.size == 1
          value_node
        end

        def check(literal, owner, findings, names, seen)
          raw = literal.unescaped
          return unless raw.is_a?(String) && raw.match?(NAME_SHAPED)

          line = literal.location.start_line
          return unless seen.add?([line, raw])

          kebab = raw.tr("_", "-")
          if names.include?(kebab)
            return if raw == kebab

            findings << Finding.new(rule: "icon-declaration", severity: :warning,
                                    message: "#{owner}: #{raw.inspect} is written snake_case - " \
                                             "icon names are kebab-case (#{kebab.to_sym.inspect} " \
                                             "is what renders)",
                                    line: line, suggestion: kebab)
          else
            findings << Finding.new(rule: "icon-declaration", severity: :warning,
                                    message: "#{owner}: #{raw.inspect} looks like an icon name " \
                                             "but is not in the icon set",
                                    line: line, suggestion: Icons.suggest(kebab, names))
          end
        end
      end

      # Reads files, lints each, attaches the file to every finding. Ruby
      # files go through the declaration tier; everything else is ERB.
      class Runner
        def initialize(catalog)
          @linter = Linter.new(catalog)
          @declarations = IconDeclarations.new(catalog)
          @stable_identity = StableIdentity.new(catalog)
        end

        def run(paths)
          paths.flat_map do |path|
            source = File.read(path)
            findings = linter_for(path).lint(source)
            # The StableId heuristics ride every ERB pass (warnings only -
            # they never flip the exit code).
            findings += @stable_identity.lint(source) unless path.end_with?(".rb")
            findings.each { |finding| finding.file = path }
          end
        end

        private

        def linter_for(path)
          path.end_with?(".rb") ? @declarations : @linter
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
