# frozen_string_literal: true

require "json"
require "yaml"

module Poetry
  module Ui
    # The dictionary half of the fidelity ledger: the structural utilities
    # a Style dictionary puts on each part, held against the classNames the
    # source puts on the same data-slot at the pin.
    #
    # The theme ledger (ThemeFidelity) proves the cn-* rules; nothing proved
    # the Ruby strings that ride the same elements - a token there wins
    # over every theme's rule at once, which is how a classic-only sizing
    # chain and a demo width overrode nine themes without a failing gate.
    #
    # Two sources are snapshotted per slot: the styled registry
    # (bases/base/ui, hooks plus structural utilities) is the contract the
    # dictionaries must match; the classic registry (new-york-v4/ui, every
    # visual utility inline) tells a classic-only token apart from a
    # poetry-only one. Hooks (cn-*) are the theme ledger's concern and are
    # left out of both sides.
    #
    # Rendered previews supply poetry's side: for every element a component
    # owns (PartContract's ownership rule), the class tokens that belong to
    # the dictionary. Reconciliation against deviations.yml is exact and
    # two-way, like the theme ledger: an unrecorded difference fails, a
    # recorded one that no longer exists fails as stale.
    module DictionaryFidelity
      # The ledger's home: the snapshot and deviations.yml.
      DIR = "config/dictionary_fidelity"
      # The styled registry (hooks plus structural utilities) - the contract.
      STYLED = "apps/v4/registry/bases/base/ui"
      # The classic registry (every visual utility inline) - tells classic-only tokens apart.
      CLASSIC = "apps/v4/registry/new-york-v4/ui"
      # Per-file presence lists the ledger records with a reason.
      LIST_KINDS = %w[missing_slots poetry_slots].freeze
      # Per-slot token diff kinds the ledger records.
      DIFF_KINDS = %w[dropped added classic].freeze
      # Top-level presence lists: source files without a poetry component and vice versa.
      COMPONENT_LISTS = %w[missing_components poetry_components].freeze
      # A theme hook (the theme ledger's concern; excluded from both sides).
      HOOK = /\Acn-/
      # A composed part: rendered by another component (a Button), whose
      # own ledger covers its tokens.
      COMPOSED = "composed"
      # The call whose balanced body carries a useRender root's props and state.
      USE_RENDER = "useRender("
      # String delimiters the tag scanner steps over.
      QUOTES = ['"', "'", "`"].freeze
      # A JSX opening tag: a component or a native element name.
      TAG_START = %r{<([A-Z][\w.]*|[a-z][\w-]*)[\s/>]}
      # Bracket characters the useRender walker balances.
      OPENERS = "({["
      # Their closing counterparts.
      CLOSERS = ")}]"

      module_function

      # Every element carrying data-slot in one source file, with the
      # structural tokens its className resolves to (string literals, cva
      # base and variant strings, render-prop classNames) and its tag.
      # Roots rendered through useRender are read from their props object.
      #
      # @param text [String] a registry .tsx file
      # @return [Hash{String => Hash}] slot => { "tag" => String, "tokens" => Array<String> }
      def extract(text)
        cvas = cva_definitions(text)
        slots = Hash.new { |h, k| h[k] = { "tag" => nil, "tokens" => [] } }
        opening_tags(text).each do |tag, attrs|
          slot = attrs[/data-slot="([^"]+)"/, 1] or next

          tokens = []
          if (expression = attrs[/className=(\{(?:[^{}]|\{[^{}]*\})*\}|"[^"]*")/, 1])
            tokens.concat(class_tokens(expression, cvas))
          end
          attrs.scan(/render=\{<\w+[^>]*className="([^"]*)"/).flatten.each { |cls| tokens.concat(cls.split) }
          entry = slots[slot]
          entry["tag"] ||= source_tag(tag)
          entry["tokens"] = (entry["tokens"] + tokens.grep_v(HOOK)).uniq
        end
        use_render_slots(text, cvas).each do |slot, tokens|
          slots[slot]["tokens"] = (slots[slot]["tokens"] + tokens.grep_v(HOOK)).uniq
        end
        slots
      end

      # The tokens a className expression resolves to: its string literals
      # plus the base and variant strings of every cva it calls.
      # @api private
      def class_tokens(expression, cvas)
        tokens = expression.scan(/"([^"]*)"/).flatten.flat_map(&:split)
        expression.scan(/(\w+)\(/).flatten.each do |call|
          definition = cvas[call] or next

          tokens.concat(definition[:base])
          definition[:variants].each_value { |values| values.each_value { |t| tokens.concat(t) } }
        end
        tokens
      end

      # The JSX opening tags of a file as [tag name, attribute text] pairs.
      # Attribute text is delimited by brace depth, so arrow functions and
      # nested render-prop elements inside attributes do not end the tag.
      # @api private
      def opening_tags(text)
        tags = []
        index = 0
        while (start = text.index(TAG_START, index))
          tag = text[start..].match(/\A<([A-Z][\w.]*|[a-z][\w-]*)/)[1]
          cursor = start + tag.length + 1
          depth = 0
          quote = nil
          while cursor < text.length
            char = text[cursor]
            if quote
              quote = nil if char == quote && text[cursor - 1] != "\\"
            elsif QUOTES.include?(char)
              quote = char
            elsif char == "{"
              depth += 1
            elsif char == "}"
              depth -= 1
            elsif char == ">" && depth.zero?
              break
            end
            cursor += 1
          end
          tags << [tag, text[(start + tag.length + 1)...cursor]]
          index = cursor + 1
        end
        tags
      end

      # Roots rendered through useRender({ props: { className: cn(xVariants(...),
      # className) }, state: { slot: "x" } }) - no JSX tag carries the slot
      # (Base UI maps state.slot to data-slot), so each call's balanced body
      # is read instead.
      # @api private
      def use_render_slots(text, cvas)
        slots = []
        index = 0
        while (start = text.index(USE_RENDER, index))
          cursor = start + USE_RENDER.length - 1
          depth = 0
          while cursor < text.length
            depth += 1 if OPENERS.include?(text[cursor])
            depth -= 1 if CLOSERS.include?(text[cursor])
            break if depth.zero?

            cursor += 1
          end
          body = text[start..cursor]
          index = cursor + 1
          slot = body[/"data-slot": "([^"]+)"/, 1] || body[/\bslot: "([^"]+)"/, 1] or next

          slots << [slot, class_tokens(body[/className: (.+)/, 1].to_s, cvas)]
        end
        slots
      end

      # `const xVariants = cva("base", { variants: { key: { value: "..." } } })`
      # definitions, by constant name.
      # @api private
      def cva_definitions(text)
        text.scan(/const (\w+) = cva\(\s*"([^"]*)"/).to_h do |name, base|
          start = text.index("const #{name} = cva(")
          depth = 0
          cursor = start + "const #{name} = cva".length
          while cursor < text.length
            depth += 1 if text[cursor] == "("
            depth -= 1 if text[cursor] == ")"
            break if depth.zero?

            cursor += 1
          end
          body = text[start..cursor]
          variants = body.scan(/^\s{6}(\w+): \{\n((?:\s{8}[\w"-]+:\s*\n?\s*"[^"]*",?\n)+)/).to_h do |key, block|
            [key, block.scan(/([\w"-]+):\s*\n?\s*"([^"]*)"/).to_h { |value, t| [value.delete('"'), t.split] }]
          end
          [name, { base: base.split, variants: variants }]
        end
      end

      # The tag a source element renders, when knowable: native elements
      # and the icon placeholder (an svg). Primitives render whatever
      # Base UI chooses; those compare as nil.
      # @api private
      def source_tag(tag)
        return "svg" if tag == "IconPlaceholder"
        return nil if tag.include?(".") || tag.match?(/\A[A-Z]/)

        tag
      end

      # The per-component diff between the source's slots and poetry's
      # rendered, owned slots. Rendered values are { "tag" => String,
      # "tokens" => Set } or COMPOSED (another component's root wearing the
      # slot - present, but its tokens are that component's ledger).
      #
      # @param source [Hash] slot => { "tag", "styled", "classic" }
      # @param rendered [Hash] slot => { "tag", "tokens" } | COMPOSED
      # @return [Hash] "missing_slots", "poetry_slots", "slots" => { slot => diff }
      def diff(source, rendered)
        result = {
          "missing_slots" => (source.keys - rendered.keys).sort,
          "poetry_slots" => (rendered.keys - source.keys).sort,
          "slots" => {}
        }
        (source.keys & rendered.keys).sort.each do |slot|
          next if rendered[slot] == COMPOSED

          entry = slot_diff(source[slot], rendered[slot])
          result["slots"][slot] = entry if entry.any?
        end
        result
      end

      # One slot's token and tag diff.
      # @api private
      def slot_diff(source, rendered)
        styled = source["styled"].to_set
        classic_only = source["classic"].to_set - styled
        tokens = rendered["tokens"]
        entry = {}
        dropped = (styled - tokens).to_a.sort
        added = (tokens - styled).to_a.sort
        classic = added & classic_only.to_a
        entry["dropped"] = dropped if dropped.any?
        entry["classic"] = classic if classic.any?
        entry["added"] = added - classic if (added - classic).any?
        if source["tag"] && rendered["tag"] && source["tag"] != rendered["tag"]
          entry["tag"] = "#{source["tag"]} -> #{rendered["tag"]}"
        end
        entry
      end

      # Every component's diff against the committed snapshot.
      #
      # @param root [String] the gem root
      # @param rendered [Hash] component key => rendered slots (see #diff)
      # @return [Hash] component key => diff, plus the two component lists
      def current_diffs(root, rendered)
        components = snapshot(root).fetch("components")
        diffs = (components.keys & rendered.keys).sort.to_h do |name|
          [name, diff(components[name], rendered[name])]
        end
        diffs["missing_components"] = (components.keys - rendered.keys).sort
        diffs["poetry_components"] = (rendered.keys - components.keys).sort
        diffs
      end

      # Exact two-way reconciliation against deviations.yml. Returns a list
      # of finding strings; empty means the contract holds.
      #
      # @param root [String] the gem root
      # @param rendered [Hash] component key => rendered slots (see #diff)
      # @return [Array<String>]
      def verify(root, rendered)
        deviations = YAML.load_file(File.join(root, DIR, "deviations.yml")) || {}
        actual = current_diffs(root, rendered)
        findings = []
        COMPONENT_LISTS.each do |kind|
          verify_list(kind, kind.tr("_", " "), actual[kind], deviations.fetch(kind, {}), findings)
        end
        (actual.keys - COMPONENT_LISTS).each do |name|
          recorded = deviations.fetch(name, {})
          LIST_KINDS.each do |kind|
            verify_list("#{name}: #{kind.tr("_", " ")}", kind.tr("_", " "), actual[name][kind],
                        recorded.fetch(kind, {}), findings)
          end
          verify_slots(name, actual[name]["slots"], recorded.fetch("slots", {}), findings)
        end
        findings
      end

      # Reconciles a presence list against the record.
      # @api private
      def verify_list(label, kind, actual_list, recorded, findings)
        recorded_list = recorded.fetch("list", nil) || []
        (actual_list - recorded_list).each do |item|
          findings << "#{label} #{item} is not recorded - add it with a reason"
        end
        (recorded_list - actual_list).each do |item|
          findings << "#{label}: recorded #{kind} #{item} no longer differs - stale entry"
        end
        findings << "#{label} needs a reason" if actual_list.any? && recorded["reason"].to_s.strip.empty?
      end

      # Reconciles a component's per-slot token diffs against the record.
      # @api private
      def verify_slots(name, actual_slots, recorded_slots, findings)
        (actual_slots.keys - recorded_slots.keys).each do |slot|
          findings << "#{name}/#{slot} deviates but is not recorded - add it with a reason"
        end
        (recorded_slots.keys - actual_slots.keys).each do |slot|
          findings << "#{name}/#{slot}: recorded deviation no longer exists - stale entry"
        end
        (actual_slots.keys & recorded_slots.keys).each do |slot|
          DIFF_KINDS.each do |kind|
            missing = (actual_slots[slot][kind] || []) - (recorded_slots[slot][kind] || [])
            stale = (recorded_slots[slot][kind] || []) - (actual_slots[slot][kind] || [])
            findings << "#{name}/#{slot} #{kind} not recorded: #{missing.join(" ")}" if missing.any?
            findings << "#{name}/#{slot} recorded #{kind} now stale: #{stale.join(" ")}" if stale.any?
          end
          if actual_slots[slot]["tag"] != recorded_slots[slot]["tag"]
            findings << "#{name}/#{slot} tag: actual #{actual_slots[slot]["tag"].inspect}, " \
                        "recorded #{recorded_slots[slot]["tag"].inspect}"
          end
          findings << "#{name}/#{slot} needs a reason" if recorded_slots[slot]["reason"].to_s.strip.empty?
        end
      end

      # Writes the frozen source snapshot from a pinned checkout: every
      # styled registry file's slots, with the classic registry's tokens for
      # the same slots beside them.
      #
      # @param root [String] the gem root
      # @param checkout [String] path to the source checkout
      # @param pin [String] the commit to read
      # @return [String] the snapshot path
      def write_snapshot(root, checkout:, pin:)
        files = `cd #{checkout} && git ls-tree --name-only #{pin} #{STYLED}/`.split("\n").grep(/\.tsx\z/)
        raise "no styled registry at #{pin}" if files.empty?

        components = files.sort.to_h do |path|
          name = File.basename(path, ".tsx")
          styled = extract(`cd #{checkout} && git show #{pin}:#{path}`)
          classic_text = `cd #{checkout} && git show #{pin}:#{CLASSIC}/#{name}.tsx 2>/dev/null`
          classic = classic_text.empty? ? {} : extract(classic_text)
          slots = styled.to_h do |slot, entry|
            [slot, { "tag" => entry["tag"], "styled" => entry["tokens"].sort,
                     "classic" => (classic.dig(slot, "tokens") || []).sort }]
          end
          [name, slots]
        end
        path = File.join(root, DIR, "upstream-#{pin}.json")
        File.write(path, JSON.pretty_generate("pin" => pin, "components" => components))
        path
      end

      # The committed snapshot.
      #
      # @param root [String] the gem root
      # @return [Hash]
      def snapshot(root)
        JSON.parse(File.read(snapshot_path(root)))
      end

      # The committed snapshot's path - exactly one may exist.
      #
      # @param root [String] the gem root
      # @return [String]
      def snapshot_path(root)
        candidates = Dir.glob(File.join(root, DIR, "upstream-*.json"))
        unless candidates.length == 1
          raise "expected exactly one #{DIR}/upstream-<pin>.json, found #{candidates.length}"
        end

        candidates.first
      end
    end
  end
end
