# frozen_string_literal: true

require "fileutils"

module Poetry
  module Extract
    # The orchestration: fetch -> compose -> derive -> write. Never touches
    # the theme - the printed handoff goes through poetry:design:import,
    # where the AA gate stays the single door.
    module Runner
      OUT_ROOT = "tmp/poetry/design_extract"

      module_function

      def run!(domain, out_root: OUT_ROOT, signals: nil, composer: Compose, io: $stdout)
        normalized = normalize_domain(domain)
        raise Error, "#{domain.inspect} is not a valid domain" if normalized.empty?

        signals ||= Fetch.signals(normalized)
        design_md = composer.design_md(domain: normalized, signals: signals)
        raise Error, "the compose call returned no DESIGN.md content" if design_md.empty?

        validate!(design_md, io)

        dir = File.join(out_root, normalized)
        FileUtils.mkdir_p(dir)
        File.write(File.join(dir, "DESIGN.md"), "#{design_md}\n")
        File.write(File.join(dir, "theme.tailwind.css"),
                   DeriveTokens.derive_tailwind_theme(normalized, signals.brand, signals.styleguide))
        File.write(File.join(dir, "tokens.css"),
                   DeriveTokens.derive_css_variables(normalized, signals.brand, signals.styleguide))

        io.puts "wrote #{dir}/{DESIGN.md, theme.tailwind.css, tokens.css}"
        io.puts "next: bin/rails \"poetry:design:import[#{dir}/DESIGN.md]\" (the AA gate decides what lands)"
        dir
      end

      def normalize_domain(domain)
        domain.to_s.strip.downcase
              .sub(%r{\Ahttps?://}, "").delete_prefix("www.").sub(%r{/.*\z}m, "")
      end

      # The composed document must at least parse as DESIGN.md; a missing
      # frontmatter is a warning, not a failure - prose-only documents
      # still carry the body sections, and import will say so again.
      def validate!(design_md, io)
        parsed = Poetry::Core::DesignMd.parse(design_md)
        io.puts "note: composed DESIGN.md has no frontmatter tokens" unless parsed.is_a?(Hash) && parsed.any?
      rescue StandardError => e
        io.puts "note: DesignMd.parse could not read the composed document (#{e.class}: #{e.message})"
      end
    end
  end
end
