# frozen_string_literal: true

require "yaml"

module Poetry
  module Generators
    # The host-facing AGENTS.md section (N13 W1): a short, registry-derived
    # pointer layer for coding agents working in the host app - llms.txt
    # stays the catalog, this is the front door to it. Marker-bounded so a
    # re-run refreshes poetry's section without touching anything the host
    # wrote around it.
    #
    # Shared by poetry:install and the standalone poetry:agents (which
    # exists so hosts that must NOT re-run install - e.g. a docs app with a
    # hand-scoped style registry - can still refresh the pointer). NOTE:
    # Thor only registers methods added directly on the generator class as
    # steps, so each generator declares its own public step and calls
    # apply_agents_section.
    module AgentsSection
      BEGIN_MARKER = "<!-- poetry:agents:begin -->"
      END_MARKER = "<!-- poetry:agents:end -->"

      def apply_agents_section
        path = File.join(destination_root, "AGENTS.md")
        if File.exist?(path) && File.read(path).include?(BEGIN_MARKER)
          gsub_file "AGENTS.md",
                    /#{Regexp.escape(BEGIN_MARKER)}.*#{Regexp.escape(END_MARKER)}/mo,
                    agents_section.chomp
        elsif File.exist?(path)
          append_to_file "AGENTS.md", "\n#{agents_section}"
        else
          create_file "AGENTS.md", agents_section
        end
      end

      def agents_section
        <<~MD
          #{BEGIN_MARKER}
          ## Building UI with poetry (#{agents_component_counts})

          - Compose with the `poetry_*` helpers; never hand-write `cn-*` classes, raw
            hex/oklch colors, or off-scale arbitrary values - tokens and variants carry
            the design.
          - Machine catalog: `/poetry/llms.txt` (index) and `/poetry/llms-full.txt`
            (full contracts + Stimulus wiring: targets / values / actions / events).
          - Verify markup before finishing: `bin/rails poetry:check` (unknown
            components/slots/variants/wiring, did-you-mean, `--json`; needs the
            `herb` gem in the Gemfile).
          - One visual theme per app (chosen at install with `--theme`); components
            read tokens, never restate them.
          - Design interop: `bin/rails poetry:design:export` writes this app's
            DESIGN.md (tokens + treatment) for external design skills.
          #{END_MARKER}
        MD
      end

      def agents_component_counts
        parts = ["#{agents_registry_size(Poetry::Ui.root)} components"]
        # Tolerant on charts: a stubbed/partial gem without a registry file
        # (the install-test stub) just drops out of the count.
        charts = defined?(Poetry::Charts::Engine) && agents_registry_size(Poetry::Charts.root)
        parts << "#{charts} chart components" if charts
        parts.join(" + ")
      end

      def agents_registry_size(root)
        path = root.join("config/component_registry.yml")
        return nil unless File.exist?(path)

        (YAML.safe_load_file(path)["components"] || {}).size
      end
    end
  end
end
