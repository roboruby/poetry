# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    class Tokens
      class GeneratorTest < Minitest::Test
        def test_tokens_css_emits_root_and_dark_blocks
          css = Generator.new.tokens_css

          assert_includes css, ":root {"
          assert_includes css, "  --radius: 0.625rem;"
          assert_includes css, "  --background: oklch(1 0 0);"
          assert_includes css, ".dark {"
          assert_includes css, "  --border: oklch(1 0 0 / 10%);"
          assert_includes css, "DO NOT EDIT"
        end

        def test_tailwind_theme_css_maps_every_color_var
          css = Generator.new.tailwind_theme_css

          assert_includes css, "@theme inline {"
          assert_includes css, "  --radius-sm: calc(var(--radius) - 4px);"
          Tokens::SHADCN_V4_COMPAT_VARS.each do |name|
            assert_includes css, "  --color-#{name}: var(--#{name});"
          end
        end

        def test_design_md_front_matter_carries_tokens_policy_and_parity
          md = Generator.new.design_md
          front = md[/\A---\n(.*?)\n---\n/m, 1]

          refute_nil front
          assert_includes front, "design_system: poetry"
          assert_includes front, "muted-foreground: oklch(0.545 0 0)"
          assert_includes front, "aa_exceptions"
          assert_includes front, "shadcn/ui v4 neutral"
        end

        # M1 DoD: change one token -> every artifact regenerates from the source.
        def test_changing_a_token_flows_into_all_artifacts
          data = JSON.parse(File.read(Tokens.default_path))
          data["color"]["light"]["primary"]["$value"]["components"] = [0.3, 0.1, 200.0]
          data["dimension"]["radius"]["$value"]["value"] = 0.5
          generator = Generator.new(tokens: Tokens.new(data))

          assert_includes generator.tokens_css, "--primary: oklch(0.3 0.1 200);"
          assert_includes generator.tokens_css, "--radius: 0.5rem;"
          assert_includes generator.design_md, "primary: oklch(0.3 0.1 200)"
        end

        def test_generate_and_verify_round_trip_in_a_sandbox
          Dir.mktmpdir do |dir|
            generator = Generator.new(root: dir)

            assert_equal Generator::ARTIFACTS.sort, generator.verify.sort, "everything missing before generate"
            generator.generate!

            assert_empty generator.verify, "fresh generation must verify clean"

            File.write(File.join(dir, "tokens", "tokens.css"), "/* tampered */\n")

            assert_equal ["tokens/tokens.css"], generator.verify, "tampering must be detected"
          end
        end

        def test_design_md_body_is_preserved_across_regeneration
          Dir.mktmpdir do |dir|
            generator = Generator.new(root: dir)
            generator.generate!
            custom_body = "\n# My constitution\n\nHand-written judgment stays.\n"
            File.write(File.join(dir, "DESIGN.md"), "---\nstale: front matter\n---\n#{custom_body}")

            regenerated = Generator.new(root: dir).design_md

            assert regenerated.end_with?(custom_body), "prose body must survive regeneration"
            assert_includes regenerated, "design_system: poetry"
            refute_includes regenerated, "stale: front matter"
          end
        end

        def test_committed_artifacts_are_in_sync_with_the_canonical_tokens
          # The drift gate as a unit test: the repo's committed tokens.css /
          # tailwind-theme.css / DESIGN.md must byte-match a fresh generation.
          assert_empty Generator.new.verify,
                       "committed token artifacts drifted - run `bin/rake tokens:generate` and commit"
        end
      end
    end
  end
end
