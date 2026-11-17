# frozen_string_literal: true

module Poetry
  module Core
    module Check
      # Applies the renames `poetry check` warns about. Two of its warnings
      # say exactly what to write instead: an option its component retired
      # in favour of another (deprecated-option), and an icon its set
      # renamed (renamed-icon). Each is one name on one line, so the fix is
      # mechanical: the old name is replaced where the finding points.
      #
      # A change is made only when the old name appears once on that line.
      # Anything else (the name twice on the line, the line no longer
      # holding it) is left as it was and reported, since a guess in
      # someone's template is worse than a warning.
      #
      # @example
      #   changes = Check::Renames.new(findings, root: Rails.root).apply
      #   changes.select(&:applied).each { |change| puts "#{change.file}:#{change.line} #{change.to}" }
      class Renames
        # The rules whose findings carry a rename.
        RULES = %w[deprecated-option renamed-icon].freeze

        # One rename: where, what was written, what replaces it, whether
        # it was made, and why not when it was not.
        Change = Struct.new(:file, :line, :from, :to, :applied, :reason, keyword_init: true)

        # A deprecated: marker as the few words every surface prints:
        # "DEPRECATED since 0.2.0 - use variant:".
        #
        # @param notice [Hash{String => String}] the registry's deprecated entry
        # @return [String]
        def self.notice(notice)
          advice = [notice["use"] && "use #{notice["use"]}:", notice["note"]].compact.join(" - ")
          "DEPRECATED#{" since #{notice["since"]}" if notice["since"]}#{" - #{advice}" unless advice.empty?}"
        end

        # The renames among a check run's findings.
        #
        # @param findings [Array<Finding>] what a check run reported
        # @param root [String, Pathname, nil] what the findings' files are relative to
        def initialize(findings, root: nil)
          @root = root && Pathname(root)
          @findings = findings.select do |finding|
            RULES.include?(finding.rule) && finding.subject && finding.suggestion && finding.file && finding.line
          end
        end

        # Makes the renames (or, with write: false, only works them out).
        #
        # @param write [Boolean] false leaves every file as it is
        # @return [Array<Change>] one per finding, made or not
        def apply(write: true)
          @findings.group_by(&:file).flat_map do |file, findings|
            path = @root ? @root.join(file) : Pathname(file)
            lines = path.readlines
            changes = findings.uniq { |finding| [finding.line, finding.rule, finding.subject] }
                              .map { |finding| change(finding, lines) }
            path.write(lines.join) if write && changes.any?(&:applied)
            changes
          end
        end

        private

        # One finding against its line: the line is rewritten in place
        # when the old name is there exactly once.
        def change(finding, lines)
          pattern, replacement = finding.rule == "renamed-icon" ? icon(finding) : option(finding)
          result = Change.new(file: finding.file, line: finding.line, from: finding.subject.to_s,
                              to: finding.suggestion.to_s, applied: false)
          line = lines[finding.line - 1]
          count = line.to_s.scan(pattern).size
          if count == 1
            lines[finding.line - 1] = line.sub(pattern) { replacement.call(Regexp.last_match) }
            result.applied = true
          else
            result.reason = count.zero? ? "not on this line as written" : "written #{count} times on this line"
          end
          result
        end

        # A retired option's keyword, and the keyword that replaces it.
        def option(finding)
          [/(?<![\w:])#{Regexp.escape(finding.subject.to_s)}:(?!:)/, ->(_match) { "#{finding.suggestion}:" }]
        end

        # An icon's old name as a symbol or a string, and the new name in
        # the same form (a symbol loses its quotes when the name allows).
        def icon(finding)
          old = Regexp.escape(finding.subject.to_s)
          current = finding.suggestion.to_s
          pattern = /:"#{old}"|:'#{old}'|"#{old}"|'#{old}'|(?<![\w:]):#{old}(?![\w-])/
          replace = lambda do |match|
            text = match[0]
            next text.sub(finding.subject.to_s, current) unless text.start_with?(":")

            current.match?(/\A[a-z_][a-z0-9_]*\z/) ? ":#{current}" : ":\"#{current}\""
          end
          [pattern, replace]
        end
      end
    end
  end
end
