# frozen_string_literal: true

module Poetry
  module Ui
    # The theme roster + per-theme DESIGN.md metadata.
    #
    # Every poetry theme shares ONE token source (poetry-core's DTCG file) -
    # a theme is a component-treatment layer (themes/<name>.css), never a
    # palette. What varies per theme, and therefore what this module knows:
    # the treatment provenance line and the typography PAIRING - which is
    # app-level metadata, not CSS (no poetry theme moves a font
    # token; upstream's create flow biases lyra to JetBrains Mono with
    # radius none and pairs sera with Noto Serif / Instrument Serif; the
    # poetry docs render system stacks keyed off the same story).
    module Themes
      SANS = "ui-sans-serif, system-ui, sans-serif"
      MONO = %(ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace)
      SERIF = %(ui-serif, Georgia, Cambria, "Times New Roman", serif)

      PORTED = "ported from upstream style-%s.css (shadcn d0fae528)"

      DETAILS = {
        "default" => {
          "typography" => { "pairing" => "system sans", "family" => SANS },
          "treatment" => "the neutral shadcn-parity treatment (new-york-v4 baseline)"
        },
        "vega" => {
          "typography" => { "pairing" => "system sans", "family" => SANS },
          "treatment" => "the vega treatment, #{format(PORTED, "vega")}"
        },
        "nova" => {
          "typography" => { "pairing" => "system sans", "family" => SANS },
          "treatment" => "the nova treatment, #{format(PORTED, "nova")}"
        },
        "mira" => {
          "typography" => { "pairing" => "system sans", "family" => SANS },
          "treatment" => "the mira treatment, #{format(PORTED, "mira")}"
        },
        "rhea" => {
          "typography" => { "pairing" => "system sans", "family" => SANS },
          "treatment" => "the rhea treatment (tinted surfaces), #{format(PORTED, "rhea")}"
        },
        "maia" => {
          "typography" => { "pairing" => "system sans", "family" => SANS },
          "treatment" => "the maia treatment, #{format(PORTED, "maia")}"
        },
        "luma" => {
          "typography" => { "pairing" => "system sans", "family" => SANS },
          "treatment" => "the luma treatment, #{format(PORTED, "luma")}"
        },
        "lyra" => {
          "typography" => { "pairing" => "system mono (upstream: JetBrains Mono, radius none)", "family" => MONO },
          "treatment" => "the lyra treatment (flat, mono-biased), #{format(PORTED, "lyra")}"
        },
        "sera" => {
          "typography" => { "pairing" => "system serif (upstream: Noto Serif / Instrument Serif)",
                            "family" => SERIF },
          "treatment" => "the sera treatment (serif-paired), #{format(PORTED, "sera")}"
        }
      }.freeze

      # A host whose installed theme slot matches no shipped fragment
      # (hand-customized bytes) still exports honestly.
      CUSTOM_DETAILS = {
        "typography" => { "pairing" => "system sans", "family" => SANS },
        "treatment" => "a customized component treatment (no byte match with a shipped poetry theme)"
      }.freeze

      class << self
        # The shipped roster, from the fragment files themselves.
        def names
          Dir[Poetry::Ui.root.join("themes/*.css").to_s].map { |file| File.basename(file, ".css") }.sort
        end

        def details(name)
          DETAILS.fetch(name) { CUSTOM_DETAILS }
        end

        # theme name -> serialized DESIGN.md, for every shipped theme - the
        # single builder rake design:export_all, the drift gate, and the
        # tests all share.
        def design_md_exports(components_count:, generator: "bin/rake design:export_all")
          tokens = Poetry::Core::Tokens.load
          names.to_h do |name|
            doc = Poetry::Core::DesignMd.build(
              tokens: tokens, theme: name,
              details: details(name).merge("components_count" => components_count, "generator" => generator)
            )
            [name, Poetry::Core::DesignMd.serialize(doc)]
          end
        end
      end
    end
  end
end
