# frozen_string_literal: true

module Poetry
  module Core
    class Tokens
      # The AAA-contrast CI gate: every semantic
      # text pair is asserted in BOTH modes against a locked ledger. WCAG 2.2
      # AA (4.5:1) is the floor; AAA (7:1) is enforced wherever it was
      # achievable at lock time. A pair may never regress below its locked
      # class - AAA pairs must stay AAA, AA exceptions must stay >= AA - so
      # any token change that degrades contrast fails the build.
      #
      # The ledger models *rendered* reality: dark destructive is gated as
      # the theme actually paints it (bg-destructive/60 composited over the page
      # background - 6.5:1); solid dark destructive under white text is 2.9:1
      # and therefore a forbidden pattern, documented here.
      #
      # A status role (success, warning, info) is gated as text through its
      # -strong companion, which is what the text-<role> utilities read: on
      # the page, on muted, and on the role's own tint (10% in light, 20%
      # in dark, as the themes tint it). The role itself is a fill and a
      # tint and is not gated as text: light success is 3.67:1 on white.
      #
      # @example
      #   gate = Poetry::Core::Tokens::ContrastGate.new(Poetry::Core::Tokens.load)
      #   gate.violations # => [] when every locked pair still holds
      #
      # @api private
      class ContrastGate
        THRESHOLDS = { aaa: 7.0, aa: 4.5 }.freeze

        # Locked against the shipped neutral theme (ratios at lock
        # in comments). :fg / :bg name color tokens; fg: :white is the literal
        # (destructive surfaces render text-white; white is not a
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
            # Dark mode renders bg-destructive/60 over the page background;
            # measure the composite (6.48). Solid dark destructive is 2.9:1 -
            # never paint white text on it undiluted.
            { fg: :white, bg: "destructive", bg_alpha: 0.6, bg_over: "background", lock: :aa }, # 6.48
            { fg: "sidebar-foreground",         bg: "sidebar",         lock: :aaa }, # 17.16
            { fg: "sidebar-primary-foreground", bg: "sidebar-primary", lock: :aa  }, #  6.54 (blue accent)
            { fg: "sidebar-accent-foreground",  bg: "sidebar-accent",  lock: :aaa }  # 14.48
          ].freeze
        }.freeze

        # The status roles as text, locked the same way. Kept apart from
        # LEDGER because LEDGER is also the door a design import is held
        # at: a status role is poetry's own and an import never maps one,
        # so an imported background is not refused for how poetry's green
        # reads on it.
        STATUS_TEXT = {
          "light" => [
            { fg: "success-strong",             bg: "background",      lock: :aa  }, #  5.19
            { fg: "success-strong",             bg: "muted",           lock: :aa  }, #  4.76
            { fg: "success-strong", bg: "success", bg_alpha: 0.1, bg_over: "background", lock: :aa }, # 4.60
            { fg: "warning-strong",             bg: "background",      lock: :aaa }, #  7.19
            { fg: "warning-strong",             bg: "muted",           lock: :aa  }, #  6.59
            { fg: "warning-strong", bg: "warning", bg_alpha: 0.1, bg_over: "background", lock: :aa }, # 6.26
            { fg: "info-strong",                bg: "background",      lock: :aaa }, #  7.56
            { fg: "info-strong",                bg: "muted",           lock: :aa  }, #  6.93
            { fg: "info-strong", bg: "info", bg_alpha: 0.1, bg_over: "background", lock: :aa } # 6.54
          ].freeze,
          "dark" => [
            { fg: "success-strong",             bg: "background",      lock: :aaa }, # 10.24
            { fg: "success-strong",             bg: "muted",           lock: :aaa }, #  7.82
            { fg: "success-strong", bg: "success", bg_alpha: 0.2, bg_over: "background", lock: :aaa }, # 7.23
            { fg: "warning-strong",             bg: "background",      lock: :aaa }, # 11.53
            { fg: "warning-strong",             bg: "muted",           lock: :aaa }, #  8.80
            { fg: "warning-strong", bg: "warning", bg_alpha: 0.2, bg_over: "background", lock: :aaa }, # 7.80
            { fg: "info-strong",                bg: "background",      lock: :aaa }, # 10.93
            { fg: "info-strong",                bg: "muted",           lock: :aaa }, #  8.34
            { fg: "info-strong", bg: "info", bg_alpha: 0.2, bg_over: "background", lock: :aaa } # 7.46
          ].freeze
        }.freeze

        # One measured ledger pair: the mode, label, ratio, lock level and verdict.
        Result = Struct.new(:mode, :label, :ratio, :lock, :pass) do
          # The result as one line: mode, label, ratio and the threshold it is held to.
          def to_s
            "[#{mode}] #{label}: #{format("%.2f", ratio)}:1 " \
              "(locked #{lock.to_s.upcase}, needs >= #{THRESHOLDS.fetch(lock)})"
          end
        end

        # A contrast gate over a token set.
        def initialize(tokens)
          @tokens = tokens
        end

        # Every ledger pair measured. The CI test asserts violations.empty?.
        def results
          [LEDGER, STATUS_TEXT].flat_map do |ledger|
            ledger.flat_map do |mode, pairs|
              pairs.map { |spec| measure(mode, spec) }
            end
          end
        end

        # The ledger pairs that fail their threshold.
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

        # Completeness for the status roles: every role's text-safe
        # companion must be gated in every mode on the page, on muted and
        # on the role's own tint. Returns [mode, label] pairs that are missing.
        def ungated_status_text
          @tokens.modes.flat_map do |mode|
            Tokens::POETRY_STATUS_VARS.flat_map do |role|
              strong = "#{role}#{Tokens::STRONG_SUFFIX}"
              gated = STATUS_TEXT.fetch(mode, []).select { |spec| spec[:fg] == strong }.map { |spec| spec[:bg] }
              surfaces = { "on background" => "background", "on muted" => "muted", "on its tint" => role }
              surfaces.reject { |_, bg| gated.include?(bg) }.map { |label, _| [mode, "#{strong} #{label}"] }
            end
          end
        end

        private

        # One ledger pair measured: the foreground against the composited background.
        def measure(mode, spec)
          fg = spec[:fg] == :white ? Color::WHITE : @tokens.color(mode, spec[:fg])
          bg = background_for(mode, spec)
          ratio = fg.contrast_ratio(bg)
          label = "#{spec[:fg] == :white ? "white" : spec[:fg]} on #{spec[:bg]}"
          label += "/#{format("%g", spec[:bg_alpha] * 100)}% over #{spec[:bg_over]}" if spec[:bg_alpha]
          Result.new(mode, label, ratio, spec[:lock], ratio >= THRESHOLDS.fetch(spec[:lock]))
        end

        # A pair's background, composited over its base when the spec gives an alpha.
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
