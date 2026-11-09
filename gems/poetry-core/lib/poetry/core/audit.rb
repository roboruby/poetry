# frozen_string_literal: true

module Poetry
  module Core
    # The consumer-app audit's analyzers, Rails-free: what a host's templates
    # exercise of the catalog (the inventory, against the registry's
    # declared axes), what they paint outside it (the token readers), where
    # they link (the flow edges) and what the check found (the health
    # summary). poetry-ui's `poetry:audit` runs them over an app, adds the
    # routes and Herb's render graph, and writes `.poetry/audit/`. Every
    # number is counted from parsed source: a value a template passes
    # dynamically is listed as dynamic, never guessed, and an edge whose
    # target is not a literal is recorded by kind, never invented.
    #
    # @api private
    module Audit
      # The Herb walks the readers share: a template's ERB code chunks, and
      # its elements' literal attributes.
      module Templates
        module_function

        # The Ruby inside a template's ERB tags, comments excluded, with the
        # line each chunk starts on.
        #
        # @param source [String] the ERB source
        # @return [Array<Array(String, Integer)>] [code, line] pairs in document order
        def erb_chunks(source)
          require "herb"
          chunks = []
          each_node(Herb.parse(source).value) do |node|
            next unless node.respond_to?(:content) && node.content.respond_to?(:value) &&
                        node.class.name.to_s.include?("ERB")
            next if node.respond_to?(:tag_opening) && node.tag_opening&.value == "<%#"

            chunks << [node.content.value, node.location.start.line]
          end
          chunks
        end

        # The literal attributes of every element, in document order; an
        # attribute whose value is ERB output contributes its literal
        # chunks only.
        #
        # @param source [String] the ERB or HTML source
        # @return [Array<Hash{String => String}>] one attribute hash per element
        def elements(source)
          require "herb"
          elements = []
          each_node(Herb.parse(source).value) do |node|
            next unless node.class.name.to_s.end_with?("HTMLElementNode")

            attrs = {}
            Array(node.open_tag&.child_nodes).compact.each do |child|
              next unless child.is_a?(Herb::AST::HTMLAttributeNode)

              key = Array(child.name&.child_nodes).compact.first
              key = key.respond_to?(:content) ? key.content : nil
              next unless key

              attrs[key] = literal_value(child.value)
            end
            elements << attrs
          end
          elements
        end

        # Yields every node under the root, depth first.
        def each_node(node, &)
          return unless node

          yield node
          node.child_nodes.compact.each { |child| each_node(child, &) } if node.respond_to?(:child_nodes)
        end

        # The literal chunks of an attribute value joined with spaces.
        def literal_value(value)
          return "" unless value

          value.child_nodes.compact.filter_map do |chunk|
            chunk.content if chunk.is_a?(Herb::AST::LiteralNode)
          end.join(" ").strip
        end

        private_class_method :each_node, :literal_value
      end

      # The inventory: components by call sites, every declared axis against
      # the literal values the templates pass, and the icons named.
      module Inventory
        module_function

        # Builds the inventory from the check's call records.
        #
        # @param calls [Array<Check::Call>] the helper calls the check recorded
        # @param catalog [Check::Catalog] the catalog the calls were checked against
        # @return [Hash] "components", "axes", "icons" and "coverage"
        def build(calls:, catalog:)
          by_helper = calls.group_by(&:helper)
          components = by_helper.map do |helper, sites|
            { "helper" => helper, "path" => catalog.path_for(helper), "call_sites" => sites.size,
              "files" => sites.filter_map(&:file).uniq.size }
          end
          components.sort_by! { |row| [-row["call_sites"], row["helper"]] }
          axes = by_helper.keys.sort.flat_map { |helper| axes_for(helper, by_helper[helper], catalog) }
          used = axes.sum { |axis| axis["used"].size }
          declared = axes.sum { |axis| axis["declared"].size }
          {
            "components" => components,
            "axes" => axes,
            "icons" => icons(calls),
            "coverage" => { "used" => used, "declared" => declared,
                            "percent" => declared.zero? ? 100 : (100.0 * used / declared).round }
          }
        end

        # One row per declared axis of a helper's component: the values
        # passed as literals, the values never passed, and how many call
        # sites pass the axis dynamically. The default counts as exercised
        # when any call site leaves the keyword off.
        def axes_for(helper, sites, catalog)
          path = catalog.path_for(helper)
          entry = path && catalog.component_entry(path)
          return [] unless entry

          axes = (entry["styles"] || []) + (entry["options"] || [])
          axes.filter_map do |axis|
            next unless axis["variants"]

            name = axis["name"]
            declared = axis["variants"].map(&:to_s)
            passed = sites.select { |site| site.keywords.key?(name) }.map { |site| site.keywords[name] }
            used = passed.compact.map(&:to_s)
            used << axis["default"].to_s if axis.key?("default") && sites.any? { |site| !site.keywords.key?(name) }
            used = (declared & used.uniq)
            { "helper" => helper, "axis" => name, "declared" => declared, "used" => used,
              "unused" => declared - used, "dynamic" => passed.count(&:nil?) }
          end
        end

        # The icons the templates name: `poetry_icon`'s name (positional or
        # `name:`) and every `icon:` keyword, with the library when a call
        # names one.
        def icons(calls)
          counts = Hash.new(0)
          calls.each do |call|
            name = call.helper == "poetry_icon" ? (call.keywords["name"] || call.positional) : nil
            name ||= call.keywords["icon"] if call.keywords.key?("icon")
            next unless name

            counts[[name.to_s, call.keywords["library"]&.to_s]] += 1
          end
          counts.map { |(name, library), uses| { "name" => name, "library" => library, "uses" => uses } }
                .sort_by { |row| [-row["uses"], row["name"]] }
        end

        private_class_method :axes_for, :icons
      end

      # The token readers: raw colors, off-scale lengths and font sizes,
      # counted from the literal class attributes of a template.
      module Tokens
        # A font-size utility, named or an arbitrary length (an arbitrary
        # color is not a size), variant-stripped.
        FONT_SIZE = /\Atext-(?:xs|sm|base|lg|[2-9]?xl|\[\d[^\]]*\])\z/

        module_function

        # One template's counts.
        #
        # @param source [String] the ERB or HTML source
        # @param catalog [Check::Catalog] the catalog, for its raw-color reader
        # @return [Hash] "raw_colors", "off_scale" and "font_sizes", each token => uses
        def scan(source, catalog:)
          raw = Hash.new(0)
          off_scale = Hash.new(0)
          sizes = Hash.new(0)
          Templates.elements(source).each do |attrs|
            classes = attrs.fetch("class", "")
            catalog.raw_colors(classes).each { |token| raw[token] += 1 }
            classes.split.each do |token|
              base = token.split(":").last
              sizes[base] += 1 if base.match?(FONT_SIZE)
              off_scale[token] += 1 if off_scale?(base)
            end
          end
          { "raw_colors" => raw, "off_scale" => off_scale, "font_sizes" => sizes }
        end

        # Whether a class token is an off-scale arbitrary length: the
        # design-slop rule's own test (a half-step rem/em value is on the
        # scale; any px value is off it).
        def off_scale?(token)
          match = token.match(DesignLint::SCALED_UTILITY)
          return false unless match

          value, unit = match.captures
          unit == "px" || !((value.to_f / 0.125) % 1).zero?
        end

        # The app-wide aggregate of per-template counts.
        #
        # @param by_file [Hash{String => Hash}] template => its scan
        # @return [Hash] "raw_colors" and "off_scale" as ranked rows, "font_sizes" with the distinct count
        #   and the templates ranked by how many sizes they carry
        def aggregate(by_file)
          templates = by_file.filter_map do |file, scan|
            next if scan["font_sizes"].empty?

            { "template" => file, "sizes" => scan["font_sizes"].keys.sort }
          end
          templates.sort_by! { |row| [-row["sizes"].size, row["template"]] }
          {
            "raw_colors" => ranked(by_file, "raw_colors"),
            "off_scale" => ranked(by_file, "off_scale"),
            "font_sizes" => { "distinct" => by_file.values.flat_map { |scan| scan["font_sizes"].keys }.uniq.size,
                              "templates" => templates }
          }
        end

        # Tokens of one kind ranked by uses, with the templates carrying each.
        def ranked(by_file, kind)
          rows = Hash.new { |hash, token| hash[token] = { "token" => token, "uses" => 0, "files" => [] } }
          by_file.each do |file, scan|
            scan[kind].each do |token, uses|
              rows[token]["uses"] += uses
              rows[token]["files"] << file
            end
          end
          rows.values.sort_by { |row| [-row["uses"], row["token"]] }
        end

        private_class_method :off_scale?, :ranked
      end

      # The flow edges: every link, form and redirect call site with its
      # target classified. A named path helper resolves exactly once the
      # routes are known; every other shape is recorded by kind with its
      # file and line.
      module Edges
        # The calls that carry a navigation target.
        EDGE_CALLS = %w[link_to button_to form_with form_for redirect_to redirect_back_or_to url_for
                        link_to_unless_current].freeze
        # A named route helper.
        PATH_HELPER = /\A[a-z0-9_]+_(?:path|url)\z/

        module_function

        # The edges in one file.
        #
        # @param source [String] an ERB template or a Ruby file
        # @param file [String] the path recorded on each edge
        # @param erb [Boolean] whether the source is ERB (its Ruby is read chunk by chunk)
        # @return [Array<Hash>] "file", "line", "call", "kind" and "target" per edge
        def scan(source, file:, erb: file.end_with?(".erb"))
          require "prism"
          chunks = erb ? Templates.erb_chunks(source) : [[source, 1]]
          chunks.flat_map do |code, base_line|
            calls = []
            collect(Prism.parse(code).value, calls)
            calls.map do |call|
              kind, target = classify(call)
              { "file" => file, "line" => base_line + call.location.start_line - 1, "call" => call.name.to_s,
                "kind" => kind, "target" => target }
            end
          end
        end

        # The calls whose target is their second positional unless a block
        # carries the label.
        LABELLED_CALLS = %i[link_to link_to_unless_current button_to].freeze

        # Collects the receiverless edge calls under a node. A call that is
        # another edge call's argument (`redirect_to url_for(...)`) is that
        # edge's target, not an edge of its own; its block is walked.
        def collect(node, into)
          return unless node

          if node.is_a?(Prism::CallNode) && node.receiver.nil? && EDGE_CALLS.include?(node.name.to_s)
            into << node
            collect(node.block, into)
          elsif node.respond_to?(:compact_child_nodes)
            node.compact_child_nodes.each { |child| collect(child, into) }
          end
        end

        # The target of a call and its kind: the `url:`/`model:` keyword
        # first, then the positional the call takes it in; `url_for` and a
        # hash alone route by hash.
        def classify(call)
          arguments = call.arguments&.arguments || []
          keywords = arguments.find { |argument| argument.is_a?(Prism::KeywordHashNode) }
          target = keywords&.elements&.find do |element|
            element.is_a?(Prism::AssocNode) && element.key.respond_to?(:unescaped) &&
              %w[url model].include?(element.key.unescaped)
          end&.value
          positionals = arguments.reject do |argument|
            argument.is_a?(Prism::KeywordHashNode) || argument.is_a?(Prism::BlockArgumentNode)
          end
          target ||= if LABELLED_CALLS.include?(call.name)
                       call.block ? positionals[0] : positionals[1]
                     else
                       positionals[0]
                     end
          target ||= keywords if keywords && %w[controller action].any? { |key| keyword?(keywords, key) }
          kind_of(target)
        end

        # Whether a keyword hash carries the key.
        def keyword?(hash, key)
          hash.elements.any? do |element|
            element.is_a?(Prism::AssocNode) && element.key.respond_to?(:unescaped) && element.key.unescaped == key
          end
        end

        # [kind, target] for a target node. A bare identifier Prism reads as
        # a call (`link_to user`) is a record or a local.
        def kind_of(target)
          case target
          when nil then ["no_target", nil]
          when Prism::CallNode
            if %i[polymorphic_path polymorphic_url url_for].include?(target.name) then ["polymorphic", nil]
            elsif target.receiver.nil? && target.name.to_s.match?(PATH_HELPER) then ["path_helper", target.name.to_s]
            elsif target.variable_call? || (target.receiver.nil? && target.arguments.nil? && target.block.nil?)
              ["record_or_variable", nil]
            else ["dynamic_call", target.name.to_s]
            end
          when Prism::StringNode then ["literal_path", target.unescaped]
          when Prism::InterpolatedStringNode then ["interpolated", nil]
          when Prism::HashNode, Prism::KeywordHashNode then ["hash_route", nil]
          when Prism::ArrayNode then ["polymorphic", nil]
          when Prism::LocalVariableReadNode, Prism::InstanceVariableReadNode then ["record_or_variable", nil]
          else ["other", nil]
          end
        end

        private_class_method :collect, :classify, :keyword?, :kind_of
      end

      # The health summary over the check's and the design tier's findings.
      module Health
        module_function

        # Counts by severity and rule, with every finding as data.
        #
        # @param findings [Array<Check::Finding>]
        # @return [Hash] "errors", "warnings", "by_rule" and "findings"
        def summarize(findings)
          by_rule = findings.group_by(&:rule).transform_values(&:size).sort_by { |rule, n| [-n, rule] }.to_h
          {
            "errors" => findings.count { |finding| finding.severity == :error },
            "warnings" => findings.count { |finding| finding.severity == :warning },
            "by_rule" => by_rule,
            "findings" => findings.map { |finding| finding.to_h.transform_keys(&:to_s) }
          }
        end
      end
    end
  end
end
