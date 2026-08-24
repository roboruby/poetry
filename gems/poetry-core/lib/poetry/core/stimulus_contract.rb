# frozen_string_literal: true

require "nokogiri"

module Poetry
  module Core
    # The DOM verifier for use_stimulus declarations - PartContract's
    # stimulus twin: reconciles a component's declared wiring against its
    # rendered previews, in both directions, so the declarations (and the
    # registry surface they feed) can never state wiring the component
    # doesn't render, nor omit wiring it does. Components without
    # declarations are skipped by callers - the mixed-world rule while the
    # migration sweeps run.
    #
    # Like PartContract.verify, verification is a pure function: the
    # caller renders the previews and supplies the HTML; nothing here
    # boots or renders.
    #
    # Scoping is by IDENTIFIER, not DOM ownership: wiring a component
    # forwards into an embedded Button (toast's action slot) speaks the
    # component's controller and is credited to it wherever it lands;
    # embedded components' own wiring speaks other identifiers and is
    # their own previews' business. The one ownership-scoped rule is
    # foreign-wiring: an OWNED node (nearest data-component is this
    # component) speaking a manifest-known identifier the declarations
    # omit - the hand-written-bypass shape.
    #
    # Rules (all errors):
    # - undeclared-controller: a rendered data-controller token of a
    #   declared identifier that no register entry produces
    # - undeclared-action:    a rendered action descriptor no declaration
    #   produces (suggestion carries a paste-ready `action` line)
    # - undeclared-target:    a rendered target no declaration produces
    # - undeclared-value:     a rendered value KEY no declaration produces
    #   (value content is render-time state - keys only)
    # - phantom-controller / phantom-action / phantom-target /
    #   phantom-value: declared wiring no preview renders - dead wiring or
    #   missing preview coverage (the declared-axis coverage rule)
    # - foreign-wiring:       hand-written wiring for an undeclared,
    #   manifest-known controller on an owned node
    #
    # @api private
    module StimulusContract
      module_function

      # @param component [Class] a component class with use_stimulus
      #   declarations (callers skip undeclared components)
      # @param docs [Array<String, #css>] every preview render
      # @return [Array<Check::Finding>]
      def verify(component:, docs:)
        elements = component.stimulus_elements.values
        return [] if elements.empty?

        declared = declared_tokens(elements)
        rendered = rendered_tokens(component.component_title, docs, declared)
        findings = []
        dom_to_declarations(findings, component, declared, rendered)
        declarations_to_dom(findings, component, declared, rendered)
        foreign_findings(findings, component, rendered)
        findings
      end

      # The declaration side, condition-blind: every entry drives a real
      # Builder into one Attributes per element, and the emitted hash is
      # parsed by the SAME parser as the rendered DOM - the two sides'
      # token formats cannot drift.
      def declared_tokens(elements)
        identifiers = elements.flat_map { |element| element.wirings.map(&:identifier) }.uniq
        tokens = empty_tokens(identifiers)
        elements.each do |element|
          attrs = HTML::Attributes.new
          element.wirings.each do |wiring|
            builder = Stimulus::Builder.new(wiring.identifier, attrs)
            wiring.entries.each { |entry| apply_entry(builder, entry) }
          end
          collect_attributes(tokens, attrs.to_attributes)
        end
        tokens
      end

      def apply_entry(builder, entry)
        case entry.kind
        when :register then builder.register_controller
        when :value then builder.with_value(entry.name, "declared")
        when :action then builder.with_action(entry.name, on: entry.on, at: entry.at)
        when :target then builder.with_target(entry.name)
        end
      end

      def rendered_tokens(title, docs, declared)
        tokens = empty_tokens(declared[:identifiers])
        docs.each do |doc|
          doc = Nokogiri::HTML5.fragment(doc.to_s) unless doc.respond_to?(:css)
          doc.css("*").each do |node|
            attributes = node.attribute_nodes.to_h { |attribute| [attribute.name, attribute.value.to_s] }
            collect_attributes(tokens, attributes)
            collect_foreign(tokens, attributes) if owned?(node, title)
          end
        end
        tokens
      end

      def empty_tokens(identifiers)
        { identifiers: identifiers, controllers: Set.new, actions: Set.new,
          targets: Set.new, values: Set.new, foreign: Set.new }
      end

      # One parser for both sides. Only tokens speaking a declared
      # identifier count; scoped keys resolve against the LONGEST known
      # identifier (manifest + declared), so poetry--core--toaster keys
      # never misparse as poetry--core--toast values.
      def collect_attributes(tokens, attributes)
        attributes.each do |name, value|
          case name
          when "data-controller"
            value.split.each { |token| tokens[:controllers] << token if tokens[:identifiers].include?(token) }
          when "data-action"
            value.split.each do |token|
              tokens[:actions] << token if tokens[:identifiers].include?(action_identifier(token))
            end
          else
            identifier, kind, rest = parse_scoped_key(name, tokens[:identifiers])
            next unless identifier && tokens[:identifiers].include?(identifier)

            case kind
            when :target then value.split.each { |target| tokens[:targets] << [identifier, target] }
            when :value then tokens[:values] << [identifier, rest]
            end
          end
        end
      end

      # Hand-written wiring for a manifest-known identifier the
      # declarations omit, on an owned node.
      def collect_foreign(tokens, attributes)
        attributes.each do |name, value|
          case name
          when "data-controller"
            value.split.each do |token|
              tokens[:foreign] << "data-controller=#{token}" if foreign?(token, tokens[:identifiers])
            end
          when "data-action"
            value.split.each do |token|
              tokens[:foreign] << "data-action=#{token}" if foreign?(action_identifier(token), tokens[:identifiers])
            end
          else
            identifier, = parse_scoped_key(name, tokens[:identifiers])
            tokens[:foreign] << name if identifier && foreign?(identifier, tokens[:identifiers])
          end
        end
      end

      def foreign?(identifier, declared)
        !declared.include?(identifier) && Stimulus::Manifest.catalog.key?(identifier)
      end

      # data-<identifier>-target / data-<identifier>-<name>-value, longest
      # known identifier first.
      def parse_scoped_key(name, declared_identifiers)
        return nil unless name.start_with?("data-") && name.length > 5

        body = name.delete_prefix("data-")
        known = (Stimulus::Manifest.catalog.keys + declared_identifiers).uniq.sort_by(&:length).reverse
        known.each do |identifier|
          next unless body.start_with?(identifier)

          rest = body.delete_prefix(identifier)
          return [identifier, :target, nil] if rest == "-target"
          return [identifier, :value, rest.delete_prefix("-").delete_suffix("-value")] if
            rest.start_with?("-") && rest.end_with?("-value")
        end
        nil
      end

      def action_identifier(token)
        token.split("->").last.to_s.split("#").first
      end

      # PartContract's ownership walk: the nearest ancestor-or-self
      # carrying data-component decides.
      def owned?(node, title)
        current = node
        while current.respond_to?(:key?)
          return current["data-component"] == title if current.key?("data-component")

          current = current.parent
        end
        false
      end

      def dom_to_declarations(findings, component, declared, rendered)
        title = component.component_title
        (rendered[:controllers] - declared[:controllers]).sort.each do |token|
          findings << finding("undeclared-controller",
                              "#{title} renders data-controller token #{token.inspect} that no " \
                              "register declaration produces")
        end
        (rendered[:actions] - declared[:actions]).sort.each do |token|
          findings << finding("undeclared-action",
                              "#{title} renders action #{token.inspect} that no declaration produces",
                              suggestion: action_scaffold(token))
        end
        (rendered[:targets] - declared[:targets]).sort.each do |(identifier, target)|
          findings << finding("undeclared-target",
                              "#{title} renders #{identifier} target #{target.inspect} that no " \
                              "declaration produces",
                              suggestion: "target :#{target.underscore}")
        end
        (rendered[:values] - declared[:values]).sort.each do |(identifier, key)|
          findings << finding("undeclared-value",
                              "#{title} renders #{identifier} value key #{key.inspect} that no " \
                              "declaration produces",
                              suggestion: "value :#{key.underscore}")
        end
      end

      def declarations_to_dom(findings, component, declared, rendered)
        title = component.component_title
        phantom(findings, title, "controller", declared[:controllers] - rendered[:controllers],
                &:inspect)
        phantom(findings, title, "action", declared[:actions] - rendered[:actions], &:inspect)
        phantom(findings, title, "target", declared[:targets] - rendered[:targets]) do |(id, target)|
          "#{target.inspect} (#{id})"
        end
        phantom(findings, title, "value", declared[:values] - rendered[:values]) do |(id, key)|
          "#{key.inspect} (#{id})"
        end
      end

      def phantom(findings, title, kind, missing, &)
        missing.sort.each do |token|
          findings << finding("phantom-#{kind}",
                              "#{title} declares #{kind} #{yield(token)} but no preview " \
                              "renders it - dead wiring or missing preview coverage")
        end
      end

      def foreign_findings(findings, component, rendered)
        rendered[:foreign].sort.each do |token|
          findings << finding("foreign-wiring",
                              "#{component.component_title} hand-writes #{token} for a controller " \
                              "its declarations omit - declare the wiring (or route it through " \
                              "stimulus_attributes) so it is validated and published")
        end
      end

      def action_scaffold(token)
        event, descriptor = token.include?("->") ? token.split("->", 2) : [nil, token]
        method = descriptor.split("#").last.to_s.underscore
        return "action :#{method}, on: :EVENT" if event.nil?

        event, at = event.split("@", 2)
        line = "action :#{method}, on: #{event.include?(":") ? event.inspect : ":#{event}"}"
        line << ", at: :#{at}" if at
        line
      end

      def finding(rule, message, suggestion: nil)
        Check::Finding.new(rule: rule, severity: :error, message: message, suggestion: suggestion)
      end
    end
  end
end
