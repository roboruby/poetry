# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module CSS
      # The shared-name contract: a host declaration of a poetry token name
      # or theme key is reported with its location and the role's use;
      # comments, unrelated names and poetry's own files never count.
      class TokenCollisionsTest < Minitest::Test
        HOST_CSS = <<~CSS
          @import "tailwindcss";
          /* --primary: in a comment is not a declaration
             --accent: nor this */
          :root {
            --accent: #ffd400;
            --brand: #1d4ed8;
            --muted: #f3f4f6;
          }
          @theme {
            --radius-sm: 1px;
            --color-primary: var(--brand);
            --font-display: "Inter";
          }
          .cn-button { --foo: 1; }
          [data-controller="poetry--core--calendar"] { color: red; }
        CSS

        def test_reports_token_names_and_theme_keys_with_location_and_role
          scan = TokenCollisions.new(sources: { "app/assets/tailwind/application.css" => HOST_CSS })

          refute_predicate scan, :ok?
          assert_equal ["--accent", "--muted", "--radius-sm", "--color-primary"], scan.collisions.map(&:name)
          assert_equal [5, 7, 10, 11], scan.collisions.map(&:line), "comment lines keep their numbers"
          assert_equal %i[token token theme_key theme_key], scan.collisions.map(&:kind)

          accent = scan.collisions.first

          assert_equal "app/assets/tailwind/application.css", accent.path
          assert_match(/hovered and highlighted rows in menus/, accent.role)
          assert_match(/application\.css:5: --accent is yours, so it wins inside poetry's components too/, accent.to_s)
          assert_match(/maps --radius-sm for the corner radius scale/, scan.collisions[2].to_s)
        end

        def test_unrelated_names_never_count
          scan = TokenCollisions.new(sources: { "a.css" => ":root { --brand: red; --font-display: x; --foo: 1; }" })

          assert_predicate scan, :ok?
          assert_match(/none of your stylesheets declare/, scan.to_text)
        end

        def test_text_report_states_the_precedence_rule
          scan = TokenCollisions.new(sources: { "a.css" => ":root { --primary: red; }" })

          assert_match(/1 poetry token name\(s\) are already declared/, scan.to_text)
          assert_match(/yours win everywhere, poetry's components included/, scan.to_text)
          assert_match(/design-overrides\.css/, scan.to_text)
        end

        def test_scan_reads_host_stylesheets_and_skips_poetry_s_own_directory
          Dir.mktmpdir do |root|
            FileUtils.mkdir_p(File.join(root, "app/assets/tailwind/poetry"))
            FileUtils.mkdir_p(File.join(root, "app/assets/stylesheets"))
            FileUtils.mkdir_p(File.join(root, "app/assets/builds"))
            File.write(File.join(root, "app/assets/tailwind/application.css"), ":root { --primary: red; }")
            File.write(File.join(root, "app/assets/stylesheets/site.css"), ".x { --ring: blue; }")
            File.write(File.join(root, "app/assets/tailwind/poetry/tokens.css"), ":root { --background: white; }")
            File.write(File.join(root, "app/assets/builds/tailwind.css"), ":root { --card: white; }")

            scan = TokenCollisions.scan(root: root)

            found = scan.collisions.map { |c| [c.path, c.name] }

            assert_equal [["app/assets/stylesheets/site.css", "--ring"],
                          ["app/assets/tailwind/application.css", "--primary"]], found
          end
        end

        def test_every_token_name_has_a_use_sentence
          scan = TokenCollisions.new(sources: {})
          missing = scan.token_names.map { |name| name.delete_prefix("--") } - TokenCollisions::ROLE_USES.keys

          assert_empty missing, "add the role's use to ROLE_USES"
        end
      end
    end
  end
end
