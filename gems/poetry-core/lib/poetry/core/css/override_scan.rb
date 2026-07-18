# frozen_string_literal: true

module Poetry
  module Core
    module CSS
      # The.cn-* override contract ( - the intent-vs-accident
      # model pointed at poetry's one un-contracted styling surface). Hosts
      # MAY restyle theme-owned cn-* classes from their own CSS (any
      # unlayered rule beats the theme's layer(base)) - but every such
      # override must be DECLARED: a dated, reasoned, scoped entry under
      # `overrides:` in config/poetry_components.yml. Undeclared overrides
      # are drift; declared ones are design intent that travels into
      # DESIGN.md's "Intentional deviations" section.
      #
      # Pure logic: {relative_path => css} sources + raw declaration hashes
      # in, findings out. The poetry:design:overrides task feeds and prints
      # it. Declaration rules (the declared-override discipline): `reason` is
      # required; `cn: "*"` must be file-scoped - a repo-wide blanket
      # cannot happen by accident.
      class OverrideScan
        CN_TOKEN = /\.(cn-[a-z0-9-]+)/
        COMMENT = %r{/\*.*?\*/}m

        Declaration = Struct.new(:cn, :files, :reason, :created, :index, :matched, keyword_init: true) do
          def wildcard? = cn == "*"

          def covers?(path, cn_class)
            return false unless wildcard? || Array(cn).include?(cn_class)
            return true if files.nil? || files.empty?

            files.any? { |glob| File.fnmatch(glob, path, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
          end
        end

        attr_reader :undeclared, :invalid, :stale, :declared_count

        def initialize(sources:, declarations:)
          @declarations, @invalid = normalize(Array(declarations))
          @undeclared = []
          @declared_count = 0
          scan(sources)
          @stale = @declarations.reject(&:matched)
        end

        def ok? = @undeclared.empty? && @invalid.empty?

        # The exact YAML to paste for an undeclared override - a finding
        # ships its own exception command (the exception-command move).
        def snippet_for(path, classes)
          cn = classes.size == 1 ? classes.first.inspect : "\"*\""
          <<~YAML
            - cn: #{cn}
              files: ["#{path}"]
              reason: "TODO - why this override is intentional"
              created: #{Time.now.strftime("%Y-%m-%d")}
          YAML
        end

        private

        def normalize(raw)
          valid = []
          invalid = []
          raw.each_with_index do |entry, index|
            unless entry.is_a?(Hash)
              invalid << "overrides[#{index}]: not a mapping"
              next
            end
            files = Array(entry["files"]).map(&:to_s)
            declaration = Declaration.new(cn: entry["cn"] || "*", files: files,
                                          reason: entry["reason"].to_s, created: entry["created"],
                                          index: index, matched: false)
            if declaration.reason.strip.empty?
              invalid << "overrides[#{index}]: `reason` is required - an override without a why is drift"
            elsif declaration.wildcard? && files.empty?
              invalid << "overrides[#{index}]: `cn: \"*\"` must be file-scoped (add `files:`) - " \
                         "a repo-wide blanket cannot happen by accident"
            else
              valid << declaration
            end
          end
          [valid, invalid]
        end

        def scan(sources)
          sources.each do |path, css|
            classes = css.gsub(COMMENT, "").scan(CN_TOKEN).flatten.uniq.sort
            next if classes.empty?

            open = classes.reject do |cn_class|
              hit = @declarations.select { |declaration| declaration.covers?(path, cn_class) }
              hit.each { |declaration| declaration.matched = true }
              @declared_count += 1 if hit.any?
              hit.any?
            end
            @undeclared << [path, open] if open.any?
          end
        end
      end
    end
  end
end
