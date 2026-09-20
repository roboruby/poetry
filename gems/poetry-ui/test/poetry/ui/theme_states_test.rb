# frozen_string_literal: true

require "test_helper"
require "yaml"
require "poetry/ui/theme_fidelity"

module Poetry
  module Ui
    # The styled-state gate: every data-* variant a theme rule applies to
    # its OWN element (data-open:, data-[variant=x]:) must name a state the
    # parts wearing that hook actually declare (Concerns::Parts). A theme
    # can style any attribute; nothing else checks that the component ever
    # emits it - which is how eight ported themes styled the command row's
    # highlight on data-selected (the source's active-row marker; poetry's
    # committed value) and lost keyboard highlight without a failing gate.
    #
    # The hook -> part mapping is the rendered truth: every registry
    # component's previews are rendered and each cn-* class is attributed
    # to the data-slot of the element wearing it. Ancestor/descendant
    # variants (group-*, peer-*, has-*, in-*, *:, **:, [&...]) condition a
    # DIFFERENT element and are out of this gate's scope; option stamps and
    # deliberate exceptions live in config/theme_states.yml (two-way: stale
    # entries fail).
    class ThemeStatesTest < ViewComponent::TestCase
      THEMES = Dir[Poetry::Ui.root.join("themes/*.css").to_s]
      ALLOWLIST = YAML.safe_load_file(Poetry::Ui.root.join("config/theme_states.yml"), aliases: true) || {}
      INFRASTRUCTURE = %w[data-slot data-component data-controller data-action].freeze
      SCOPE_SHIFT = /\A(\*|\*\*|\[.*\])\z/ # the rest of the token conditions another element
      OTHER_ELEMENT = /\A(group|peer|has|in)-/ # a condition on another element; skip the segment

      def test_every_styled_state_is_a_declared_state_of_a_part_wearing_the_hook
        hooks = rendered_hooks
        declared = declared_states
        allow_attrs = (ALLOWLIST["attrs"] || []).to_h { |e| [e["attr"], e["reason"]] }
        allow_rules = (ALLOWLIST["rules"] || []).to_h { |e| [[e["hook"], e["attr"]], e["reason"]] }
        used_attrs = Set.new
        used_rules = Set.new
        findings = []

        THEMES.each do |path|
          theme = File.basename(path, ".css")
          Poetry::Ui::ThemeFidelity.parse_css(File.read(path)).each do |selector, rule|
            hook = selector.delete_prefix(".")
            attrs = Array(rule["apply"]).flat_map { |token| own_state_attrs(token) }.uniq - INFRASTRUCTURE
            next if attrs.empty?

            next unless hooks.key?(hook) # not rendered by any preview - css:verify_hooks owns worn-ness

            worn = hooks[hook]

            parts = worn.to_a.sort
            declared_here = parts.flat_map { |slot| declared[slot].to_a }.uniq
            attrs.each do |attr|
              if allow_attrs.key?(attr)
                used_attrs << attr
              elsif allow_rules.key?([hook, attr])
                used_rules << [hook, attr]
              elsif !declared_here.include?(attr)
                findings << "#{theme}: #{selector} styles #{attr} - worn by #{parts.join(", ")}, " \
                            "which declare: #{declared_here.sort.join(" ")}"
              end
            end
          end
        end

        (allow_attrs.keys - used_attrs.to_a).each do |attr|
          findings << "config/theme_states.yml: attrs entry #{attr} is stale (no rule styles it)"
        end
        (allow_rules.keys - used_rules.to_a).each do |hook, attr|
          findings << "config/theme_states.yml: rules entry #{hook}/#{attr} is stale"
        end

        assert_empty findings.uniq, "#{findings.uniq.size} styled-state finding(s):\n\n#{findings.uniq.join("\n")}"
      end

      private

      # hook (cn-*) => Set of data-slot names of elements wearing it, from
      # every registry component's rendered previews. Elements without a
      # slot map to "(unnamed)" - they may not carry state (the part
      # contract forbids it), so any state a rule styles on them is a finding.
      def rendered_hooks
        hooks = Hash.new { |h, k| h[k] = Set.new }
        registry_components.each do |component|
          preview_docs(component).each do |html|
            Nokogiri::HTML5.fragment(html).css("[class]").each do |node|
              slot = node["data-slot"] || "(unnamed)"
              node["class"].split(/\s+/).each { |token| hooks[token] << slot if token.start_with?("cn-") }
            end
          end
        end
        hooks
      end

      # slot name => Set of declared state attributes, merged across every
      # component that declares the part (a slot name can be shared).
      def declared_states
        declared = Hash.new { |h, k| h[k] = Set.new }
        registry_components.each do |component|
          component.part_definitions.each do |part|
            Array(part["states"]).each { |state| declared[part["name"]] << state["attr"] }
          end
        end
        declared
      end

      # The data-* attributes a token conditions on ITS OWN element.
      def own_state_attrs(token)
        segments = split_variants(token)
        segments.pop # the utility
        attrs = []
        segments.each do |segment|
          break if segment.match?(SCOPE_SHIFT)
          next if segment.match?(OTHER_ELEMENT)

          segment = segment.delete_prefix("not-")
          attrs << attribute_name(segment) if segment.start_with?("data-")
        end
        attrs.compact
      end

      def attribute_name(segment)
        match = segment.match(/\Adata-\[([a-z][a-z0-9-]*)(?:[$^*|~]?=[^\]]*)?\]\z/) ||
                segment.match(/\Adata-([a-z][a-z0-9-]*)\z/)
        "data-#{match[1]}" if match
      end

      # Split a Tailwind token on ":" outside brackets/parens.
      def split_variants(token)
        parts = []
        depth = 0
        current = +""
        token.each_char do |char|
          case char
          when "[", "(" then depth += 1
          when "]", ")" then depth -= 1
          end
          if char == ":" && depth.zero?
            parts << current
            current = +""
          else
            current << char
          end
        end
        parts << current
      end

      def registry_components
        @registry_components ||= Poetry::Core::Registry.new(source_root: Poetry::Ui.root).components
      end

      def preview_docs(component)
        preview = component.name.sub(/Component\z/, "Preview").constantize
        preview.examples.map do |example|
          render_preview(example, from: preview)
          rendered_content
        end
      rescue NameError
        []
      end
    end
  end
end
