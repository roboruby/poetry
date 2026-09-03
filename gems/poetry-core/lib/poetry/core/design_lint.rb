# frozen_string_literal: true

module Poetry
  module Core
    # Design-slop detectors: deterministic rules for the checkable design
    # axes, catalog-aware (the AST knows what a Card IS) and scoped to the
    # on-distribution defaults generated UIs drift toward: cards in cards,
    # the icon-tile-over-heading hero, walls of identical cards, off-scale
    # values, token-less gradients, heading skips, center-everything,
    # stacked shadows, type-scale monotony, invisible surface boundaries.
    # No LLM scoring here - measured runs showed cold aesthetic judgment is
    # near chance; deterministic rules + paired judges are the defensible
    # modes.
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
    #
    # @api private
    module DesignLint
      # id => [tier, rationale] - the design discipline each rule enforces.
      RULES = {
        "card-in-card" => [:ast, "nesting discipline: a card never frames another card"],
        "icon-tile-over-heading" => [:ast, "the stock AI hero tell (icon chip above heading)"],
        "wall-of-cards" => [:ast, "macrostructure variety: identical cards repeated read as filler"],
        "off-scale-arbitrary" => [:ast, "spacing scale discipline: arbitrary lengths break the scale"],
        "gradient-off-token" => [:ast, "the purple-blue gradient tell; raw colors bypass the tokens"],
        "heading-skip" => [:ast, "document outline audit (WCAG 1.3.1 adjacent)"],
        "mixed-status-weight" => [:ast, "one status set, one treatment - " \
                                        "solid and soft badge pills must not mix in one table"],
        "center-everything" => [:ast, "centered-body-copy tell"],
        "shadow-stack" => [:ast, "one elevation level per surface"],
        "type-scale-monotony" => [:dom, "type hierarchy audit: a page painted in one size has no hierarchy"],
        "adjacent-same-surface" => [:dom, "surface separation audit"],
        "contrast-adjacent" => [:dom, "boundary legibility as a measurable axis"],
        "stock-theme-nudge" => [:dom, "refuses the default look when a brand exists"],
        # Copy/composition tells that CAN fire on poetry surfaces
        # (off-token color/border tells cannot).
        "em-dash-overuse" => [:ast, ">=5 em dashes in page copy - the LLM prose tell"],
        "marketing-buzzword" => [:ast, "stock SaaS phrases in page copy"],
        "aphoristic-cadence" => [:ast, "'Not a X. Y.' manufactured-contrast cadence"],
        "numbered-section-markers" => [:ast, "sequential 01/02/03 section markers"],
        "repeated-section-kickers" => [:ast, "tracked-caps kicker above every section heading"],
        "hero-eyebrow-chip" => [:ast, "tracked-caps/accent text eyebrow above the h1"],
        "oversized-h1" => [:ast, "72px+ display h1 carrying long copy"],
        # Motion floor: perception-physics rules, theme-independent - they
        # read the utility classes the same in host ERB (poetry check /
        # design:lint) and in the extracted theme layer (design:motion
        # self-audit). Only patterns poetry itself never ships are ENFORCED
        # here, so the floor never false-positives on the gem's own rendered
        # output. transition-all is pervasive in the upstream-ported theme
        # layer, so it is a REPORT-ONLY advisory (transition_all_advisory /
        # design:motion), NOT an enforced rule. The softer preferences
        # (ease-in-out on enters) and timing TOKENS are the later
        # tokenize/conformance tiers.
        "motion-ease-in" => [:ast, "motion floor: ease-in decelerates wrong for UI enters"],
        "motion-duration-ceiling" => [:ast, "motion floor: UI transition over ~500ms reads as laggy"],
        "motion-scale-from-zero" => [:ast, "motion floor: scale-from-0 entries erupt from nothing"]
      }.freeze

      # Spacing/sizing/type utilities where an arbitrary length is off-scale.
      SCALED_UTILITY = /\A-?(?:[mp][trblxyse]?|gap(?:-[xy])?|space-[xy]|text|leading|w|h|size|
                            min-w|min-h|max-w|max-h|top|right|bottom|left|inset(?:-[xy])?|
                            rounded(?:-[a-z]+)?)-\[(\d[\d.]*)(px|rem|em)\]\z/x
      GRADIENT = /\Abg-(?:gradient-to-[a-z]+|linear-|radial|conic)/
      SHADOW = /\Ashadow(?:\z|-(?!none)[a-z0-9]+\z)/
      HEADING = /\Ah([1-6])\z/

      # Motion floor: the floor governs TRANSITIONS - discrete state
      # changes. An element is subject to it when it carries a transition-*
      # utility (a bare `duration-`/`ease-`/`scale-0` is inert or ambiguous
      # without one). Continuous keyframe loops (animate-spin, animate-pulse,
      # animate-caret-blink) legitimately run long/linear and are EXEMPT -
      # they are animations, not transitions. Durations are milliseconds in
      # Tailwind (duration-700 = 700ms); the UI transition ceiling is ~500ms.
      TRANSITION_DECLARED = /\Atransition(?:-|\z)/
      DURATION_TOKEN = /\Aduration-(\d+)\z/
      DURATION_ARBITRARY = /\Aduration-\[(\d+(?:\.\d+)?)(m?s)\]\z/
      SCALE_ZERO = /\Ascale(?:-[xy])?-0\z/
      UI_DURATION_CEILING_MS = 500

      # The lint tree: HTML elements plus poetry_* call blocks as
      # pseudo-nodes, so "Card inside Card" is checkable whether the card is
      # a helper call (consumer ERB) or rendered markup (eval arms).
      #
      # @api private
      Node = Struct.new(:kind, :tag, :classes, :attrs, :helper, :line, :children, :parent, :texts,
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
        copy_tells(root, findings)
        repeated_section_kickers(root, findings)
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
        root = Node.new(kind: :root, classes: [], attrs: {}, children: [], texts: [])
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
                            line: child.location.start.line, children: [], texts: [], parent: tree_parent)
            tree_parent.children << node
            append_children(child, node)
          when "HTMLTextNode"
            tree_parent.texts << child.content if child.respond_to?(:content)
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
                 children: [], texts: [], parent: parent)
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
          hero_eyebrow_chip(child, node.children[index + 1], findings)
          class_token_rules(child, findings) if child.element?
          findings.concat(motion_class_findings(child.classes, child.line)) if child.element?
          oversized_h1(child, findings)
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

      # The ENFORCED motion floor, PUBLIC so the
      # theme-layer self-audit (design:motion) runs the identical rules over
      # the @apply utilities it extracts. Only patterns poetry itself never
      # ships are here, so the floor never false-positives on the gem's own
      # rendered components. An over-ceiling duration is wrong whatever
      # triggers it, so it reads the variant-stripped base (data-open:
      # duration-700 still counts); ease-in and scale-0 are only wrong as the
      # WHOLE transition or the rest state - a state-scoped data-closed:
      # ease-in / data-closed:scale-0 is a legitimate exit target, so those
      # match the bare, unprefixed token only.
      def motion_class_findings(classes, line)
        bases = classes.map { |token| token.split(":").last }
        return [] unless bases.any? { |base| base.match?(TRANSITION_DECLARED) }

        findings = []
        if classes.include?("ease-in")
          findings << finding("motion-ease-in", line,
                              "ease-in accelerates into the rest state - wrong for UI (enters feel " \
                              "sluggish, exits abrupt); use ease-out for enters, ease-in-out for moves")
        end
        if (over = motion_over_ceiling(bases))
          findings << finding("motion-duration-ceiling", line,
                              "#{over}ms is above the UI motion ceiling (~#{UI_DURATION_CEILING_MS}ms) - UI " \
                              "transitions past ~300ms read as laggy; shorten it")
        end
        # A bare scale-0 rest state pops from a point - UNLESS it fades in
        # too (a co-present opacity-0): at scale-0 the element is invisible,
        # so the erupt is never seen. That is the standard icon crossfade
        # (rest at scale-0 opacity-0, animate to scale-100 opacity-100), not
        # slop; only a scale pop without a fade is flagged.
        if classes.any? { |token| token.match?(SCALE_ZERO) } && !classes.include?("opacity-0")
          findings << finding("motion-scale-from-zero", line,
                              "an animated element rests at scale-0 with no opacity fade - scaling up " \
                              "from nothing erupts into view; start from scale-95, or fade with opacity-0")
        end
        findings
      end

      # The report-only transition-all advisory. transition-all is
      # pervasive in the upstream-ported theme layer, so enforcing it would
      # fail poetry's own rendered gates and force a nine-theme re-timing - a
      # design decision, surfaced by design:motion rather than gated. NOT a
      # registered RULE (lint never emits it); the message says so.
      def transition_all_advisory(classes, line)
        bases = classes.map { |token| token.split(":").last }
        return [] unless bases.include?("transition-all")

        [finding("motion-transition-all", line,
                 "transition-all animates every property, including layout; prefer the specific " \
                 "properties (transition-colors / transition-[color,box-shadow] / transition-transform). " \
                 "ADVISORY - poetry ships the upstream default here; re-timing is a design decision")]
      end

      def motion_over_ceiling(bases)
        bases.each do |base|
          if (match = base.match(DURATION_TOKEN))
            ms = match[1].to_i
          elsif (match = base.match(DURATION_ARBITRARY))
            ms = match[2] == "s" ? (match[1].to_f * 1000).round : match[1].to_i
          else
            next
          end
          return ms if ms > UI_DURATION_CEILING_MS
        end
        nil
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

      # One status set, one treatment: the
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

      def each_table(node, &)
        yield node if node.element? && node.tag == "table"
        node.children.each { |child| each_table(child, &) }
      end

      def collect_badge_variants(node, variants)
        if node.element? && node.attrs["data-slot"] == "badge" && node.attrs["data-variant"]
          variants << [node.attrs["data-variant"], node.line]
        end
        node.children.each { |child| collect_badge_variants(child, variants) }
      end

      # --- tranche 2: the copy/composition tells ----------------------------

      # Page copy is the joined static text OUTSIDE code/kbd contexts - em
      # dashes and `01` tokens inside code samples are content, not design.
      COPY_EXEMPT_TAGS = %w[pre code kbd script style].freeze

      # A curated cut of a 28-phrase stock-SaaS list: the phrases
      # a model reaches for when no copy direction was given.
      BUZZWORDS = [
        "streamline your", "enterprise-grade", "harness the power", "unlock the power",
        "supercharge", "seamlessly integrate", "revolutionize", "game-changing",
        "next-generation", "cutting-edge", "empower your", "to the next level",
        "all-in-one platform", "built for scale", "lightning-fast", "blazingly fast",
        "future-proof", "world-class", "effortlessly", "in seconds, not"
      ].freeze

      # "Not a X. Y." manufactured contrast + "X. No Y. Just Z." rebuttal.
      # The lookbehind keeps the shared period unconsumed so back-to-back
      # rebuttals ("No config. Just results.") each count.
      APHORISM_PATTERNS = [
        /\b[Nn]ot (?:a|an|just|your) [^.!?\n]{2,60}\.\s+[A-Z][^.!?\n]{1,40}\./,
        /(?<=[.!?])\s+(?:no [a-z][a-z -]{1,30}\.|just [a-z][a-z -]{1,30}\.)/i
      ].freeze

      def copy_tells(root, findings)
        text = page_copy(root)
        return if text.length < 80 # fragments carry no prose signal

        em_dash_overuse(text, findings)
        marketing_buzzword(text, findings)
        aphoristic_cadence(text, findings)
        numbered_section_markers(text, findings)
      end

      def page_copy(root)
        chunks = []
        collect_copy(root, chunks)
        chunks.join(" ").squeeze(" ")
      end

      def collect_copy(node, chunks)
        return if node.element? && COPY_EXEMPT_TAGS.include?(node.tag)

        chunks.concat(node.texts) if node.texts
        node.children.each { |child| collect_copy(child, chunks) }
      end

      def em_dash_overuse(text, findings)
        count = text.count("—")
        return if count < 5

        findings << finding("em-dash-overuse", nil,
                            "#{count} em dashes in the page copy - the LLM prose tell; rewrite " \
                            "most as periods, commas, or parentheses")
      end

      def marketing_buzzword(text, findings)
        down = text.downcase
        hits = BUZZWORDS.select { |phrase| down.include?(phrase) }
        return if hits.size < 3

        findings << finding("marketing-buzzword", nil,
                            "stock SaaS copy: #{hits.first(4).map(&:inspect).join(", ")} - say what " \
                            "the product concretely does instead")
      end

      def aphoristic_cadence(text, findings)
        count = APHORISM_PATTERNS.sum { |pattern| text.scan(pattern).size }
        return if count < 3

        findings << finding("aphoristic-cadence", nil,
                            "#{count} manufactured-contrast constructions (\"Not a X. Y.\" / " \
                            "\"No X. Just Y.\") - one lands, #{count} read as generated copy")
      end

      def numbered_section_markers(text, findings)
        # Two-digit tokens only, and at least one zero-padded (01-09): "3
        # steps" and prices must never count; "01 02 03" editorial markers do.
        tokens = text.scan(/(?<![\d.,:$])(0[1-9]|1[0-2])(?![\d.,:%])/).flatten
        return unless tokens.any? { |t| t.start_with?("0") }

        numbers = tokens.map(&:to_i).uniq.sort
        return if numbers.size < 3
        return unless numbers.each_cons(2).count { |a, b| b == a + 1 } >= 2

        findings << finding("numbered-section-markers", nil,
                            "sequential section markers (#{numbers.first(4).map { |n| format("%02d", n) }.join(" ")}" \
                            ") - the numbered-editorial tell; cut the numbers or vary the anatomy")
      end

      # Tracked-caps kicker above section headings: one is an accent, one per
      # section is the template tell. Nav/breadcrumb chrome never counts.
      def repeated_section_kickers(root, findings)
        kickers = []
        collect_kickers(root, kickers)
        return if kickers.size < 3

        findings << finding("repeated-section-kickers", kickers[2].line,
                            "#{kickers.size} tracked-caps kickers above headings on one page - " \
                            "the sectioned-template tell; keep at most one, or vary section openers")
      end

      def collect_kickers(node, kickers)
        return if node.element? && (node.tag == "nav" || node.attrs["role"] == "navigation" ||
                                    node.attrs["aria-label"].to_s.downcase.include?("breadcrumb"))

        node.children.each_cons(2) do |candidate, heading|
          next unless candidate.element? && heading.element? && heading.heading_level.to_i.between?(2, 4)
          next unless kicker_classes?(candidate)

          kickers << candidate
        end
        node.children.each { |child| collect_kickers(child, kickers) }
      end

      def kicker_classes?(node)
        node.classes.include?("uppercase") &&
          node.classes.any? { |c| c.start_with?("tracking-") } &&
          node.attrs["data-slot"] != "badge"
      end

      # Text eyebrow directly above the h1 - the stock AI hero opener. The
      # icon-tile variant has its own rule; badges (announcement pills) are a
      # deliberate pattern and never count.
      def hero_eyebrow_chip(node, next_sibling, findings)
        return unless node.element? && next_sibling&.element? && next_sibling.heading_level == 1
        return if node.attrs["data-slot"] == "badge" || node.texts.to_a.join.strip.empty?
        return unless kicker_classes?(node) ||
                      (node.classes.any? { |c| c.match?(/\Afont-(semibold|bold)\z/) } &&
                       node.classes.include?("text-primary"))

        findings << finding("hero-eyebrow-chip", node.line,
                            "text eyebrow directly above the h1 - the stock AI hero opener; fold " \
                            "it into the heading or cut it")
      end

      # 72px+ display type carrying a full sentence: display sizes are for
      # 2-6 word statements.
      OVERSIZED_TEXT = %w[text-7xl text-8xl text-9xl].freeze

      def oversized_h1(node, findings)
        return unless node.element? && node.heading_level == 1
        return unless node.classes.intersect?(OVERSIZED_TEXT)
        return if node.texts.to_a.join(" ").strip.length < 40

        findings << finding("oversized-h1", node.line,
                            "display-size h1 (#{(node.classes & OVERSIZED_TEXT).first}) carrying " \
                            "40+ characters - shorten the headline or step the size down")
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
        # Typeset prose owns its hierarchy in the app-owned
        # stylesheet's em-derived element rules - nested :where() CSS the
        # static renderer cannot compute, so every element reads as the
        # base size. Bare-element prose is the pattern, not the slop.
        nodes = nodes.reject do |el|
          el.ancestors.any? { |a| a["class"].to_s.split(/\s+/).include?("typeset") }
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
