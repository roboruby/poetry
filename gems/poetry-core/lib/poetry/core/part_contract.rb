# frozen_string_literal: true

require "nokogiri"

module Poetry
  module Core
    # The DOM verifier for the part contract: reconciles a
    # component's declared parts (Concerns::Parts) against its rendered
    # previews, in both directions. an upstream library type-checks its styles-api
    # keys against a factory union but never checks the DOM; this module
    # checks the DOM, so the registry-published contract cannot state a
    # part, state attribute, or var seam the component doesn't render -
    # nor omit one it does.
    #
    # Like DesignLint.lint_dom, verification is a pure function: the
    # caller (poetry-ui/charts' part_contract_test) renders the previews
    # and supplies the HTML; nothing here boots or renders.
    #
    # Ownership: a data-slot element belongs to the component whose
    # data-component root is its nearest ancestor-or-self - embedded
    # components (a Button inside a Card preview) attribute their parts
    # to themselves, never to the composition they sit in.
    #
    # Rules (all errors):
    # - missing-root:        no rendered element carries data-component=<title>
    # - slotless-component:  previews render no owned data-slot at all -
    #                        the anatomy is unstylable and undocumentable
    # - undeclared-part:     a rendered part the contract omits (the
    #                        suggestion carries a paste-ready `part` line)
    # - phantom-part:        a declared part no preview renders
    # - undeclared-state:    a rendered state attribute the part omits
    # - unverified-state:    a declared state never rendered, outside the
    #                        setState vocabulary, absent from the sources
    # - unknown-state-value: a rendered value outside the declared values
    # - undeclared-var:      an inline custom property the part omits
    # - unverified-var:      a declared var never rendered inline and
    #                        absent from the sources
    # - unnamed-stateful:    an owned element carrying state attributes or
    #                        var seams without a data-slot name
    module PartContract
      # Ruby mirror of app/javascript/poetry/core/helpers/state.js
      # VOCABULARY (the attributes setState can write). JS-toggled states
      # (data-open flips at runtime) verify against this list when no
      # preview renders them server-side; a sync test asserts the mirror
      # matches the JS source.
      STATE_VOCABULARY = %w[
        data-open data-closed data-popup-open data-panel-open
        data-checked data-unchecked data-indeterminate
        data-pressed data-active data-selected
      ].freeze

      # Wiring and identity attributes - not styleable state: the two
      # anatomy markers, the Stimulus grammar, Turbo, and test plumbing.
      INFRASTRUCTURE = %w[data-slot data-component data-controller data-action].freeze
      INFRASTRUCTURE_PATTERNS = [
        /\Adata-.+-(?:target|value|outlet|param)\z/, # Stimulus per-identifier grammar
        /\Adata-poetry-/, # poetry's own wiring grammar (collection membership et al)
        /\Adata-turbo/,
        /\Adata-testid\z/
      ].freeze

      VAR_DECLARATION = /(--[a-z][a-z0-9-]*)\s*:/

      module_function

      # @param title [String] the component_title (its data-component value)
      # @param parts [Array<Hash>] registry-shaped part entries
      # @param docs [Array<String, #css>] every preview render (HTML or
      #   pre-parsed Nokogiri nodes)
      # @param sources [String] the component's own source text plus the
      #   JS corpus - the second source for JS-applied states and vars
      # @return [Array<Check::Finding>]
      def verify(title:, parts:, docs:, sources: "")
        observed = observe(title, docs)
        findings = []
        root_findings(findings, title, observed, parts)
        dom_to_contract(findings, title, observed, parts)
        contract_to_dom(findings, title, observed, parts, sources)
        unnamed_findings(findings, title, observed)
        findings
      end

      # The rendered truth: every owned part with its state attributes
      # (attr => Set of rendered values) and inline vars, plus the owned
      # elements that carry state without a part name.
      def observe(title, docs)
        parts = Hash.new do |hash, key|
          hash[key] = { states: Hash.new { |states, attr| states[attr] = Set.new }, vars: Set.new }
        end
        observed = { parts: parts, root_seen: false, unnamed: [] }
        docs.each do |doc|
          doc = Nokogiri::HTML5.fragment(doc.to_s) unless doc.respond_to?(:css)
          doc.css("[data-component]").each do |node|
            observed[:root_seen] ||= node["data-component"] == title
          end
          doc.css("*").each { |node| observe_node(observed, title, node) }
        end
        observed
      end

      def observe_node(observed, title, node)
        return unless owned?(node, title)

        states = state_attributes(node)
        vars = inline_vars(node)
        if (slot = node["data-slot"])
          entry = observed[:parts][slot]
          states.each { |attr, value| entry[:states][attr] << value }
          vars.each { |var| entry[:vars] << var }
        elsif states.any? || vars.any?
          observed[:unnamed] << "<#{node.name} #{(states.keys + vars.to_a).sort.join(" ")}>"
        end
      end

      def owned?(node, title)
        current = node
        while current.respond_to?(:key?)
          return current["data-component"] == title if current.key?("data-component")

          current = current.parent
        end
        false
      end

      def state_attributes(node)
        node.attribute_nodes.each_with_object({}) do |attribute, states|
          name = attribute.name
          next unless name.start_with?("data-")
          next if INFRASTRUCTURE.include?(name)
          next if INFRASTRUCTURE_PATTERNS.any? { |pattern| name.match?(pattern) }

          states[name] = attribute.value.to_s
        end
      end

      def inline_vars(node)
        (node["style"] || "").scan(VAR_DECLARATION).map(&:first)
      end

      def root_findings(findings, title, observed, parts)
        unless observed[:root_seen]
          findings << finding("missing-root",
                              "no preview renders data-component=#{title.inspect} - the component " \
                              "never identifies its root")
        end
        return unless observed[:parts].empty? && parts.empty? && observed[:root_seen]

        findings << finding("slotless-component",
                            "#{title}: previews render no data-slot at all - name the anatomy " \
                            "(the root at minimum) so it can be styled and contracted")
      end

      def dom_to_contract(findings, title, observed, parts)
        declared = parts.to_h { |part| [part["name"], part] }
        observed[:parts].sort.each do |name, seen|
          part = declared[name]
          unless part
            findings << finding("undeclared-part",
                                "#{title} renders data-slot=#{name.inspect} but the contract omits it",
                                suggestion: scaffold(name, seen))
            next
          end
          state_reconciliation(findings, title, part, seen)
          var_reconciliation(findings, title, part, seen)
        end
      end

      def state_reconciliation(findings, title, part, seen)
        declared = (part["states"] || []).to_h { |state| [state["attr"], state] }
        seen[:states].sort.each do |attr, values|
          state = declared[attr]
          unless state
            findings << finding("undeclared-state",
                                "#{title}/#{part["name"]} renders #{attr} but the contract omits it")
            next
          end
          next unless state["values"]

          (values.reject(&:empty?) - state["values"]).sort.each do |value|
            findings << finding("unknown-state-value",
                                "#{title}/#{part["name"]} renders #{attr}=#{value.inspect}, outside " \
                                "the declared values #{state["values"].inspect}")
          end
        end
      end

      def var_reconciliation(findings, title, part, seen)
        seen[:vars].sort.each do |var|
          next if (part["vars"] || []).any? { |declared| var_match?(declared["name"], var) }

          findings << finding("undeclared-var",
                              "#{title}/#{part["name"]} sets #{var} inline but the contract omits it")
        end
      end

      def contract_to_dom(findings, title, observed, parts, sources)
        parts.each do |part|
          seen = observed[:parts][part["name"]] if observed[:parts].key?(part["name"])
          unless seen
            findings << finding("phantom-part",
                                "#{title} declares part #{part["name"].inspect} but no preview " \
                                "renders it - dead contract or missing preview coverage")
            next
          end
          declared_states(findings, title, part, seen, sources)
          declared_vars(findings, title, part, seen, sources)
        end
      end

      def declared_states(findings, title, part, seen, sources)
        (part["states"] || []).each do |state|
          attr = state["attr"]
          next if seen[:states].key?(attr)
          next if STATE_VOCABULARY.include?(attr)
          next if sources.include?(attr)

          findings << finding("unverified-state",
                              "#{title}/#{part["name"]} declares #{attr} but no preview renders it, " \
                              "it is outside the setState vocabulary, and the sources never mention it")
        end
      end

      def declared_vars(findings, title, part, seen, sources)
        (part["vars"] || []).each do |var|
          name = var["name"]
          next if seen[:vars].any? { |rendered| var_match?(name, rendered) }
          next if sources.include?(name.delete_suffix("*"))

          findings << finding("unverified-var",
                              "#{title}/#{part["name"]} declares #{name} but no preview sets it " \
                              "inline and the sources never mention it")
        end
      end

      def unnamed_findings(findings, title, observed)
        observed[:unnamed].uniq.sort.each do |element|
          findings << finding("unnamed-stateful",
                              "#{title} renders #{element} with state or var seams but no data-slot " \
                              "- name the part so the surface is stylable")
        end
      end

      # A declared var matches exactly, or by prefix when it declares a
      # dynamic family with a trailing * (charts' --color-*).
      def var_match?(declared, rendered)
        if declared.end_with?("*")
          rendered.start_with?(declared.delete_suffix("*"))
        else
          declared == rendered
        end
      end

      # A paste-ready `part` line carrying the rendered truth - the tier
      # doubles as the roster scaffold generator.
      def scaffold(name, seen)
        line = "part #{name.inspect}, \"TODO\""
        if seen[:states].any?
          states = seen[:states].keys.sort.map { |attr| "#{attr.inspect} => \"TODO\"" }
          line << ", states: { #{states.join(", ")} }"
        end
        if seen[:vars].any?
          vars = seen[:vars].sort.map { |var| "#{var.inspect} => \"TODO\"" }
          line << ", vars: { #{vars.join(", ")} }"
        end
        line
      end

      def finding(rule, message, suggestion: nil)
        Check::Finding.new(rule: rule, severity: :error, message: message, suggestion: suggestion)
      end
    end
  end
end
