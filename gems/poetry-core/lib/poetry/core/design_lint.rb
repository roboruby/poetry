# frozen_string_literal: true

module Poetry
  module Core
    # Design-slop detectors (N14 W3): deterministic rules for the checkable
    # design axes, poetry's analogue of external rule sets and
    # 57 slop gates - but catalog-aware (the AST knows what a Card IS), and
    # scoped to the on-distribution defaults those skills fight: cards in
    # cards, the icon-tile-over-heading hero, walls of identical cards,
    # off-scale values, token-less gradients, heading skips,
    # center-everything, stacked shadows, type-scale monotony, invisible
    # surface boundaries. No LLM scoring here - the lesson: cold
    # aesthetic judgment is near chance; deterministic rules + paired judges
    # (N15) are the defensible modes.
    #
    # Two tiers, one Finding vocabulary (Check::Finding - file:line, message
    # that names the fix, JSON/text via Check.to_json/to_text):
    #
    #   - the AST tier rides the same herb walk as `poetry check`, and
    #     parses plain HTML just as well as ERB - so the eval harness runs
    #     the identical rules on every arm (scorer portability);
    #   - the DOM tier reads COMPUTED styles (the dommy tier in poetry-ui,
    #     no browser needed) for what markup cannot show: the painted type
    #     scale and surface boundaries.
    #
    # Every rule is a warning: this is the taste tier, `poetry check`'s
    # mechanical errors stay the hard gate. rake design:lint (poetry-ui)
    # exits non-zero on any finding - the dogfood surfaces stay clean.
    module DesignLint
      # id => [tier, provenance] - the analogue each rule descends from.
      RULES = {
        "card-in-card" => [:ast, "slop gate: cards-in-cards; the design-rule analogue: nesting depth"],
        "icon-tile-over-heading" => [:ast, "the slop-gate analogue: the stock AI hero tell (icon chip above heading)"],
        "wall-of-cards" => [:ast, "the slop-gate analogue: macrostructure variety; the design-rule analogue: repetition audit"],
        "off-scale-arbitrary" => [:ast, "the design-rule analogue: spacing scale discipline (extends)"],
        "gradient-off-token" => [:ast, "the slop-gate analogue: purple-blue gradient tell; raw-color posture"],
        "heading-skip" => [:ast, "the design-rule analogue: document outline audit (WCAG 1.3.1 adjacent)"],
        "mixed-status-weight" => [:ast, "Blocks v1.1 (lead): one status set, one treatment - " \
                                        "solid and soft badge pills must not mix in one table"],
        "center-everything" => [:ast, "the slop-gate analogue: centered-body-copy tell"],
        "shadow-stack" => [:ast, "the design-rule analogue: one elevation level per surface"],
        "type-scale-monotony" => [:dom, "the design-rule analogue: type hierarchy audit; checkable design axis"],
        "adjacent-same-surface" => [:dom, "the design-rule analogue: surface separation audit"],
        "contrast-adjacent" => [:dom, "boundary legibility as a measurable axis"],
        "stock-theme-nudge" => [:dom, "the slop-gate analogue: refuses the default look when a brand exists"]
      }.freeze

      # Spacing/sizing/type utilities where an arbitrary length is off-scale.
      SCALED_UTILITY = /\A-?(?:[mp][trblxyse]?|gap(?:-[xy])?|space-[xy]|text|leading|w|h|size|
                            min-w|min-h|max-w|max-h|top|right|bottom|left|inset(?:-[xy])?|
                            rounded(?:-[a-z]+)?)-\[(\d[\d.]*)(px|rem|em)\]\z/x
      GRADIENT = /\Abg-(?:gradient-to-[a-z]+|linear-|radial|conic)/
      SHADOW = /\Ashadow(?:\z|-(?!none)[a-z0-9]+\z)/
      HEADING = /\Ah([1-6])\z/

      # The lint tree: HTML elements plus poetry_* call blocks as
      # pseudo-nodes, so "Card inside Card" is checkable whether the card is
      # a helper call (consumer ERB) or rendered markup (eval arms).
      Node = Struct.new(:kind, :tag, :classes, :attrs, :helper, :line, :children, :parent,
                        keyword_init: true) do
        def element? = kind == :element
        def heading_level = tag&.match(HEADING) && Regexp.last_match(1).to_i

        def card?
          return helper == "poetry_card" unless element?

          attrs["data-slot"] == "card" || classes.include?("cn-card") ||
            (classes.include?("border") && classes.any? { |c| c.start_with?("rounded") } &&
              (classes.any?(SHADOW) || classes.include?("bg-card")))
        end

        def signature
          element? ? "#{tag}##{classes.sort.join(".")}" : "call##{helper}"
        end

        def ancestors
          list = []
          node = parent
          while node
            list << node
            node = node.parent
          end
          list
        end
      end

      module_function

      # AST tier over one ERB or HTML source string. Returns [Check::Finding].
      def lint(source, file: nil)
        require "herb"
        root = build_tree(Herb.parse(source).value)
        findings = []
        walk_rules(root, findings)
        heading_skips(root, findings)
        center_everything(root, findings)
        mixed_status_weight(root, findings)
        findings.sort_by! { |finding| [finding.line || 0, finding.rule] }
        findings.each { |finding| finding.file = file }
      end

      # DOM tier over a rendered page: `doc` is a Nokogiri node, `styles` a
      # callable (element) -> computed-style hash with the CSS property names
      # used below (the dommy tier provides it; nil skips style rules).
      # `context` carries host facts for the nudge rule.
      def lint_dom(doc:, styles: nil, context: {}, file: nil)
        findings = []
        if styles
          type_scale_monotony(doc, styles, findings)
          surface_boundaries(doc, styles, findings)
        end
        stock_theme_nudge(context, findings)
        findings.each { |finding| finding.file = file }
      end

      # --- tree ----------------------------------------------------------

      def build_tree(ast)
        root = Node.new(kind: :root, classes: [], attrs: {}, children: [])
        append_children(ast, root)
        root
      end

      def append_children(ast_node, tree_parent)
        ast_node.child_nodes.compact.each do |child|
          case child.class.name.split("::").last
          when "HTMLElementNode"
            node = element_node(child, tree_parent)
            tree_parent.children << node
            append_children(child, node)
          when "ERBBlockNode"
            helper = child.content.value[/\bpoetry_[a-z_]+/] if child.respond_to?(:content)
            node = Node.new(kind: helper ? :call : :block, helper: helper, classes: [], attrs: {},
                            line: child.location.start.line, children: [], parent: tree_parent)
            tree_parent.children << node
            append_children(child, node)
          else
            append_children(child, tree_parent) if child.respond_to?(:child_nodes)
          end
        end
      end

      def element_node(ast_el, parent)
        attrs = {}
        open_tag = ast_el.respond_to?(:open_tag) ? ast_el.open_tag : nil
        Array(open_tag&.child_nodes).compact.each do |child|
          next unless child.is_a?(Herb::AST::HTMLAttributeNode)

          name = literal_content(child.name)
          attrs[name] = attribute_literal(child) if name
        end
        Node.new(kind: :element, tag: ast_el.tag_name&.value.to_s.downcase, attrs: attrs,
                 classes: attrs.fetch("class", "").split, line: ast_el.location.start.line,
                 children: [], parent: parent)
      end

      def literal_content(node)
        first = Array(node&.child_nodes).compact.first
        first.respond_to?(:content) ? first.content : nil
      end

      def attribute_literal(attribute)
        value = attribute.value
        return "" unless value

        value.child_nodes.compact.filter_map do |chunk|
          chunk.content if chunk.is_a?(Herb::AST::LiteralNode)
        end.join(" ").strip
      end

      # --- AST rules -------------------------------------------------------

      def walk_rules(node, findings, stack = [])
        node.children.each_with_index do |child, index|
          card_in_card(child, findings) if child.card? && stack.any?(&:card?)
          icon_tile_over_heading(child, node.children[index + 1], findings)
          class_token_rules(child, findings) if child.element?
          shadow_stack(child, findings)
          wall_of_cards(node, findings) if index.zero?
          walk_rules(child, findings, stack + [child])
        end
      end

      def card_in_card(node, findings)
        findings << finding("card-in-card", node.line,
                            "Card nested directly inside a Card - flatten, or use a plain " \
                            "bordered section (slop tell: cards-in-cards)")
      end

      def icon_tile_over_heading(node, next_sibling, findings)
        return unless node.element? && next_sibling&.element? && next_sibling.heading_level
        return unless node.classes.any? { |c| c.start_with?("rounded") } &&
                      node.classes.any? { |c| c.start_with?("bg-") }
        return unless icon_only?(node)

        findings << finding("icon-tile-over-heading", node.line,
                            "icon in a tinted tile directly above a heading - the stock AI hero " \
                            "pattern; put the icon inline with the heading or drop the tile")
      end

      def icon_only?(node)
        meaningful = node.children.reject { |child| child.kind == :block }
        return false unless meaningful.size == 1

        child = meaningful.first
        (child.element? && child.tag == "svg") || child.helper == "poetry_icon"
      end

      def class_token_rules(node, findings)
        node.classes.each do |token|
          if (match = token.match(SCALED_UTILITY))
            value, unit = match.captures
            next if unit != "px" && ((value.to_f / 0.125) % 1).zero? # on the half-step scale

            findings << finding("off-scale-arbitrary", node.line, off_scale_message(token, value.to_f, unit))
          elsif token.match?(GRADIENT)
            findings << finding("gradient-off-token", node.line,
                                "#{token} paints a gradient outside the token surface - use a " \
                                "semantic background (bg-primary, bg-muted, ...) or theme the surface")
          end
        end
      end

      def off_scale_message(token, value, unit)
        px = unit == "px" ? value : value * 16
        prefix = token[/\A-?[a-z-]+(?=-\[)/]
        if (px % 1).zero? && (px % 2).zero? # an exact half-step: the scale already spells it
          "#{token} is the scale value #{prefix}-#{format("%g", px / 4.0)} - use the scale spelling"
        else
          lower = (px / 2).floor * 2
          steps = [lower, lower + 2].map { |step| "#{prefix}-#{format("%g", step / 4.0)} = #{step}px" }
          "#{token} is off the spacing/type scale - use the nearest step (#{steps.join(" / ")}) or add a token"
        end
      end

      def shadow_stack(node, findings)
        return unless node.element? && node.classes.any?(SHADOW)
        return unless node.ancestors.any? { |ancestor| ancestor.element? && ancestor.classes.any?(SHADOW) }

        findings << finding("shadow-stack", node.line,
                            "shadow on a child of an already-shadowed surface - keep one " \
                            "elevation level per surface (drop the inner shadow)")
      end

      def wall_of_cards(parent, findings)
        elements = parent.children.select(&:card?)
        return if elements.size < 4

        run = elements.each_cons(4).find { |group| group.map(&:signature).uniq.size == 1 }
        return unless run

        findings << finding("wall-of-cards", run.first.line,
                            "#{elements.size} identical cards in a row - vary the anatomy, or use " \
                            "a list/table for homogeneous records")
      end

      def heading_skips(root, findings)
        levels = []
        collect_headings(root, levels)
        levels.each_cons(2) do |(prev, _), (level, line)|
          next unless level > prev + 1

          findings << finding("heading-skip", line,
                              "h#{prev} jumps to h#{level} - keep heading levels sequential " \
                              "(insert h#{prev + 1} or demote)")
        end
      end

      def collect_headings(node, levels)
        levels << [node.heading_level, node.line] if node.element? && node.heading_level
        node.children.each { |child| collect_headings(child, levels) }
      end

      # One status set, one treatment (Blocks v1.1, a lead): the v1.1
      # table arm mixed a solid destructive "Overdue" pill into a soft
      # success/warning column and the judge called the inconsistency out.
      # Detection rides the rendered badge markup (data-slot/data-variant) -
      # a badge call's kwargs are invisible to the ERB pseudo-node, so the
      # rule bites where the eval gate and design:lint read: rendered HTML.
      SOLID_BADGE_VARIANTS = %w[default destructive].freeze
      SOFT_BADGE_VARIANTS = %w[success warning info].freeze

      def mixed_status_weight(root, findings)
        each_table(root) do |table|
          variants = []
          collect_badge_variants(table, variants)
          solid = (variants.map(&:first) & SOLID_BADGE_VARIANTS)
          soft = (variants.map(&:first) & SOFT_BADGE_VARIANTS)
          next unless solid.any? && soft.any?

          line = variants.find { |variant, _line| solid.include?(variant) }&.last || table.line
          findings << finding("mixed-status-weight", line,
                              "one table mixes solid (#{solid.join(", ")}) and soft " \
                              "(#{soft.join(", ")}) badge pills - status sets read as a set: " \
                              "keep one treatment family per surface")
        end
      end

      def each_table(node, &block)
        yield node if node.element? && node.tag == "table"
        node.children.each { |child| each_table(child, &block) }
      end

      def collect_badge_variants(node, variants)
        if node.element? && node.attrs["data-slot"] == "badge" && node.attrs["data-variant"]
          variants << [node.attrs["data-variant"], node.line]
        end
        node.children.each { |child| collect_badge_variants(child, variants) }
      end

      def center_everything(root, findings)
        centered = []
        collect_centered(root, centered)
        return if centered.size < 3

        findings << finding("center-everything", centered[2].line,
                            "text-center on #{centered.size} blocks in one template - center only " \
                            "heroes and empty states; left-align body copy")
      end

      # Centered CELLS are correct design (day grids, numeric columns,
      # buttons) - the rule targets centered body COPY, so grid/table
      # subtrees and cell/control elements never count.
      CENTERED_EXEMPT_TAGS = %w[button td th table].freeze
      CENTERED_EXEMPT_ROLES = %w[grid gridcell cell columnheader rowheader row table].freeze

      def collect_centered(node, centered)
        return if node.element? &&
                  (CENTERED_EXEMPT_TAGS.include?(node.tag) || CENTERED_EXEMPT_ROLES.include?(node.attrs["role"]))

        centered << node if node.element? && node.classes.include?("text-center")
        node.children.each { |child| collect_centered(child, centered) }
      end

      # --- DOM rules -------------------------------------------------------

      # Content text only - controls (buttons, labels) and data cells are
      # legitimately uniform; monotony is a CONTENT-hierarchy signal.
      TEXT_ELEMENTS = "h1, h2, h3, h4, h5, h6, p, li, blockquote"

      def type_scale_monotony(doc, styles, findings)
        nodes = doc.css(TEXT_ELEMENTS).select { |el| el.text.strip.length.positive? }
        # Navigation chrome (pagination, menus) is legitimately uniform.
        nodes = nodes.reject do |el|
          el.name == "li" && el.ancestors.any? { |a| a.name == "nav" || a["role"] == "navigation" }
        end
        nodes = nodes.select { |el| rendered?(styles.call(el)) }
        return if nodes.size < 6

        sizes = nodes.filter_map { |el| styles.call(el)["font-size"] }.uniq
        return if sizes.size >= 2

        findings << finding("type-scale-monotony", nil,
                            "#{nodes.size} text elements all render at #{sizes.first} - give the " \
                            "page a type hierarchy (text-xl+ headings, text-sm support)")
      end

      # Boundary exemptions, each a deliberate design pattern, not slop:
      # composite controls share surfaces (segmented buttons, toolbars);
      # landmark regions may differ by a subtle tint (the sidebar rail);
      # non-rendered elements (closed popups in the initial DOM) paint
      # nothing.
      INTERACTIVE_TAGS = %w[button a input select textarea].freeze
      INTERACTIVE_ROLES = %w[button tab menuitem menuitemcheckbox menuitemradio option radio switch].freeze
      LANDMARK_TAGS = %w[aside main nav header footer].freeze
      LANDMARK_ROLES = %w[complementary main navigation banner contentinfo region].freeze

      def surface_boundaries(doc, styles, findings)
        doc.css("*").each do |parent|
          children = parent.element_children
          next if children.size < 2

          gap = styles.call(parent)["gap"].to_s
          next unless gap.empty? || gap == "0px" || gap == "normal"

          children.each_cons(2) do |a, b|
            check_boundary(a, b, styles, findings)
          end
        end
      end

      def interactive?(element)
        INTERACTIVE_TAGS.include?(element.name) || INTERACTIVE_ROLES.include?(element["role"])
      end

      def landmark?(element)
        LANDMARK_TAGS.include?(element.name) || LANDMARK_ROLES.include?(element["role"])
      end

      def rendered?(computed)
        computed["display"].to_s != "none" && computed["visibility"].to_s != "hidden"
      end

      def check_boundary(first, second, styles, findings)
        return if interactive?(first) && interactive?(second)
        return if landmark?(first) || landmark?(second)
        return unless rendered?(styles.call(first)) && rendered?(styles.call(second))

        bg_a = surface_color(styles.call(first))
        bg_b = surface_color(styles.call(second))
        return unless bg_a && bg_b
        return if bordered?(styles.call(first)) || bordered?(styles.call(second))

        if bg_a.css == bg_b.css
          findings << finding("adjacent-same-surface", nil,
                              "adjacent siblings paint the same surface (#{bg_a.css}) with no " \
                              "border, shadow, or gap - the boundary is invisible; separate or merge them")
        elsif bg_a.contrast_ratio(bg_b) < 1.1
          findings << finding("contrast-adjacent", nil,
                              "adjacent surfaces differ by #{format("%.2f", bg_a.contrast_ratio(bg_b))}:1 " \
                              "(#{bg_a.css} vs #{bg_b.css}) - indistinguishable; add a border or more contrast")
        end
      end

      def surface_color(computed)
        color = Tokens::Color.parse(computed["background-color"].to_s)
        return unless color&.alpha&.positive?
        return if shadowed?(computed)

        color
      end

      # Some computed-style engines (dommy) never aggregate the border-width
      # shorthand - the per-side property is the reliable read.
      def bordered?(computed)
        %w[border-width border-top-width].any? do |property|
          width = computed[property].to_s
          !width.empty? && width != "0px"
        end
      end

      def shadowed?(computed)
        shadow = computed["box-shadow"].to_s
        !shadow.empty? && shadow != "none"
      end

      def stock_theme_nudge(context, findings)
        return unless context[:design_md_present] && !context[:overrides_present]

        findings << finding("stock-theme-nudge", nil,
                            "a DESIGN.md exists but no design-overrides.css - the app paints the " \
                            "stock theme while a brand is on disk; run " \
                            "bin/rails 'poetry:design:import[DESIGN.md]'")
      end

      def finding(rule, line, message)
        Check::Finding.new(rule: rule, severity: :warning, message: message, line: line)
      end
    end
  end
end
