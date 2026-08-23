# frozen_string_literal: true

module Poetry
  module Core
    class Tokens
      # The AAA-contrast CI gate (locked 2026-06-24): every semantic
      # text pair is asserted in BOTH modes against a locked ledger. WCAG 2.2
      # AA (4.5:1) is the floor; AAA (7:1) is enforced wherever it was
      # achievable at lock time. A pair may never regress below its locked
      # class - AAA pairs must stay AAA, AA exceptions must stay >= AA - so
      # any token change that degrades contrast fails the build.
      #
      # The ledger models *rendered* reality: dark destructive is gated as
      # shadcn actually paints it (bg-destructive/60 composited over the page
      # background - 6.5:1); solid dark destructive under white text is 2.9:1
      # and therefore a forbidden pattern, documented here.
      #
      # @example
      #   gate = Poetry::Core::Tokens::ContrastGate.new(Poetry::Core::Tokens.load)
      #   gate.violations # => [] when every locked pair still holds
      class ContrastGate
        THRESHOLDS = { aaa: 7.0, aa: 4.5 }.freeze

        # Locked 2026-07-01 against the shipped neutral theme (ratios at lock
        # in comments). :fg / :bg name color tokens; fg: :white is the literal
        # (shadcn's destructive surfaces render text-white; white is not a
        # token). :bg_alpha + :bg_over composite the bg before measuring.
        LEDGER = {
          "light" => [
            { fg: "foreground",                 bg: "background",      lock: :aaa }, # 19.79
            { fg: "card-foreground",            bg: "card",            lock: :aaa }, # 19.79
            { fg: "popover-foreground",         bg: "popover",         lock: :aaa }, # 19.79
            { fg: "primary-foreground",         bg: "primary",         lock: :aaa }, # 17.16
            { fg: "secondary-foreground",       bg: "secondary",       lock: :aaa }, # 16.42
            { fg: "muted-foreground",           bg: "muted",           lock: :aa  }, #  4.54 (parity delta)
            { fg: "muted-foreground",           bg: "background",      lock: :aa  }, #  4.96
            { fg: "accent-foreground",          bg: "accent",          lock: :aaa }, # 16.42
            { fg: :white,                       bg: "destructive",     lock: :aa  }, #  4.76
            { fg: "sidebar-foreground",         bg: "sidebar",         lock: :aaa }, # 18.96
            { fg: "sidebar-primary-foreground", bg: "sidebar-primary", lock: :aaa }, # 17.16
            { fg: "sidebar-accent-foreground",  bg: "sidebar-accent",  lock: :aaa }  # 16.42
          ].freeze,
          "dark" => [
            { fg: "foreground",                 bg: "background",      lock: :aaa }, # 18.96
            { fg: "card-foreground",            bg: "card",            lock: :aaa }, # 17.16
            { fg: "popover-foreground",         bg: "popover",         lock: :aaa }, # 17.16
            { fg: "primary-foreground",         bg: "primary",         lock: :aaa }, # 14.22
            { fg: "secondary-foreground",       bg: "secondary",       lock: :aaa }, # 14.48
            { fg: "muted-foreground",           bg: "muted",           lock: :aa  }, #  5.83
            { fg: "muted-foreground",           bg: "background",      lock: :aaa }, #  7.63
            { fg: "accent-foreground",          bg: "accent",          lock: :aaa }, # 14.48
            # shadcn dark renders bg-destructive/60 over the page background;
            # measure the composite (6.48). Solid dark destructive is 2.9:1 -
            # never paint white text on it undiluted.
            { fg: :white, bg: "destructive", bg_alpha: 0.6, bg_over: "background", lock: :aa }, # 6.48
            { fg: "sidebar-foreground",         bg: "sidebar",         lock: :aaa }, # 17.16
            { fg: "sidebar-primary-foreground", bg: "sidebar-primary", lock: :aa  }, #  6.54 (blue accent)
            { fg: "sidebar-accent-foreground",  bg: "sidebar-accent",  lock: :aaa }  # 14.48
          ].freeze
        }.freeze

        Result = Struct.new(:mode, :label, :ratio, :lock, :pass) do
          def to_s
            "[#{mode}] #{label}: #{format("%.2f", ratio)}:1 " \
              "(locked #{lock.to_s.upcase}, needs >= #{THRESHOLDS.fetch(lock)})"
          end
        end

        def initialize(tokens)
          @tokens = tokens
        end

        # Every ledger pair measured. The CI test asserts violations.empty?.
        def results
          LEDGER.flat_map do |mode, pairs|
            pairs.map { |spec| measure(mode, spec) }
          end
        end

        def violations
          results.reject(&:pass)
        end

        # Completeness: every *-foreground token (plus the bare foreground)
        # must be gated in every mode, so a newly added role can't silently
        # ship ungated. Returns [mode, name] pairs that are missing.
        def ungated_foregrounds
          @tokens.modes.flat_map do |mode|
            gated = LEDGER.fetch(mode, []).map { |spec| spec[:fg] }
            @tokens.color_names(mode)
                   .select { |name| name == "foreground" || name.end_with?("-foreground") }
                   .reject { |name| gated.include?(name) }
                   .map { |name| [mode, name] }
          end
        end

        private

        def measure(mode, spec)
          fg = spec[:fg] == :white ? Color::WHITE : @tokens.color(mode, spec[:fg])
          bg = background_for(mode, spec)
          ratio = fg.contrast_ratio(bg)
          label = "#{spec[:fg] == :white ? "white" : spec[:fg]} on #{spec[:bg]}"
          label += "/#{format("%g", spec[:bg_alpha] * 100)}% over #{spec[:bg_over]}" if spec[:bg_alpha]
          Result.new(mode, label, ratio, spec[:lock], ratio >= THRESHOLDS.fetch(spec[:lock]))
        end

        def background_for(mode, spec)
          base = @tokens.color(mode, spec[:bg])
          return base unless spec[:bg_alpha]

          translucent = Color.new(l: base.l, c: base.c, h: base.h, alpha: spec[:bg_alpha])
          translucent.composite_over(@tokens.color(mode, spec[:bg_over]))
        end
      end
    end
  end
end
