# frozen_string_literal: true

module Poetry
  module Docs
    # The icon-set gems beyond Lucide, for their /icons/<slug> pages and
    # markdown mirrors. One record each; the styles, counts and the pin are
    # read from the gems themselves, so a re-vendor updates the pages.
    module IconSets
      # One icon-set gem as its page shows it.
      IconSet = Data.define(:slug, :title, :gem, :namespace, :homepage, :repository, :license, :license_file,
                            :styles, :samples, :react, :blurb) do
        # The gem's module (Poetry::Tabler).
        def module = Poetry.const_get(namespace)

        # Each style: library key, what it looks like, icon count.
        def rows
          self.module.sets.map { |key, set| { key: key, style: styles.fetch(key), count: set.names.size } }
        end

        def total = rows.sum { |row| row[:count] }

        def vendored_commit = self.module.vendored_commit
      end

      ALL = [
        IconSet.new(
          slug: "tabler", title: "Tabler Icons", gem: "poetry-tabler", namespace: :Tabler,
          homepage: "https://tabler.io/icons", repository: "tabler/tabler-icons",
          license: "MIT", license_file: "LICENSE-TABLER.txt",
          styles: { tabler: "outline, a 2px stroke like Lucide's", tabler_filled: "filled" },
          samples: %w[home search settings user bell heart star trash],
          react: "`IconHome` from `@tabler/icons-react` is `name: :home, library: :tabler`; " \
                 "`IconHomeFilled` is `library: :tabler_filled`.",
          blurb: "The largest outline set in the registry corpus, drawn on Lucide's grid and stroke, " \
                 "so it sits beside Lucide without a seam."
        ),
        IconSet.new(
          slug: "hugeicons", title: "Hugeicons", gem: "poetry-hugeicons", namespace: :Hugeicons,
          homepage: "https://hugeicons.com", repository: "hugeicons/hugeicons",
          license: "MIT", license_file: "LICENSE-HUGEICONS.txt",
          styles: { hugeicons: "stroke rounded, 1.5px" },
          samples: %w[home-01 search-01 settings-01 user notification-01 favourite star delete-02],
          react: "`Home01Icon` from `@hugeicons/core-free-icons` is `name: :\"home-01\", library: :hugeicons`.",
          blurb: "Hugeicons' free set, the stroke-rounded style. Upstream hardcodes a dark grey on every " \
                 "path; the vendoring turns it into currentColor, so the icons take the text colour."
        ),
        IconSet.new(
          slug: "phosphor", title: "Phosphor", gem: "poetry-phosphor", namespace: :Phosphor,
          homepage: "https://phosphoricons.com", repository: "phosphor-icons/core",
          license: "MIT", license_file: "LICENSE-PHOSPHOR.txt",
          styles: { phosphor: "regular", phosphor_bold: "bold", phosphor_duotone: "duotone",
                    phosphor_fill: "fill", phosphor_light: "light", phosphor_thin: "thin" },
          samples: %w[house magnifying-glass gear user bell heart star trash],
          react: "`<House weight=\"bold\" />` from `@phosphor-icons/react` is " \
                 "`name: :house, library: :phosphor_bold`; with no weight it is `library: :phosphor`.",
          blurb: "All six weights, one library key each. Phosphor draws filled shapes on a 256-unit grid; " \
                 "the set carries that viewBox, so the icons size like any other."
        ),
        IconSet.new(
          slug: "heroicons", title: "Heroicons", gem: "poetry-heroicons", namespace: :Heroicons,
          homepage: "https://heroicons.com", repository: "tailwindlabs/heroicons",
          license: "MIT", license_file: "LICENSE-HEROICONS.txt",
          styles: { heroicons: "outline, 24px", heroicons_solid: "solid, 24px",
                    heroicons_mini: "mini, solid at 20px", heroicons_micro: "micro, solid at 16px" },
          samples: %w[home magnifying-glass cog-6-tooth user bell heart star trash],
          react: "`HomeIcon` from `@heroicons/react/24/outline` is `name: :home, library: :heroicons`; " \
                 "`/24/solid` is `:heroicons_solid`, `/20/solid` `:heroicons_mini` and `/16/solid` " \
                 "`:heroicons_micro`.",
          blurb: "The four Heroicons styles, each drawn at its own size: mini and micro keep their 20 and " \
                 "16 pixel boxes."
        ),
        IconSet.new(
          slug: "simple-icons", title: "Simple Icons", gem: "poetry-simple_icons", namespace: :SimpleIcons,
          homepage: "https://simpleicons.org", repository: "simple-icons/simple-icons",
          license: "CC0 1.0", license_file: "LICENSE-SIMPLE-ICONS.txt",
          styles: { simple_icons: "brand logos, one colour" },
          samples: %w[github ruby rubyonrails postgresql redis docker cloudflare tailwindcss],
          react: "`SiGithub` from `@icons-pack/react-simple-icons` is `name: :github, library: :simple_icons`; " \
                 "its `color=\"default\"` is the brand colour from `Poetry::SimpleIcons.brand(:github)`.",
          blurb: "Brand logos, each with its brand's name and colour. Simple Icons dedicates the SVG data to " \
                 "the public domain; the marks stay their owners' trademarks, and the gem ships the " \
                 "project's disclaimer."
        ),
        IconSet.new(
          slug: "solar", title: "Solar", gem: "poetry-solar", namespace: :Solar,
          homepage: "https://www.figma.com/community/file/1166831539721848736", repository: "saoudi-h/solar-icons",
          license: "CC BY 4.0", license_file: "LICENSE-SOLAR.txt",
          styles: { solar: "linear", solar_bold: "bold", solar_bold_duotone: "bold duotone", solar_broken: "broken",
                    solar_line_duotone: "line duotone", solar_outline: "outline" },
          samples: %w[home magnifier settings user bell heart star trash-bin-trash],
          react: "`HomeIcon` from `@solar-icons/react/linear` is `name: :home, library: :solar`; `/bold` is " \
                 "`:solar_bold`, `/bold-duotone` `:solar_bold_duotone`, `/broken` `:solar_broken`, " \
                 "`/line-duotone` `:solar_line_duotone` and `/outline` `:solar_outline`.",
          blurb: "The Solar Icon Set by 480 Design in all six styles. The icons are CC BY 4.0, and every one " \
                 "carries its credit inside the svg, so a page that serves them complies without extra work."
        ),
        IconSet.new(
          slug: "blode", title: "Blode Icons", gem: "poetry-blode", namespace: :Blode,
          homepage: "https://blode.co", repository: "mblode/blode-icons",
          license: "MIT", license_file: "LICENSE-BLODE.txt",
          styles: { blode: "outline, 2px stroke", blode_filled: "filled" },
          samples: %w[home magnifying-glass settings-gear-1 bell heart calendar-days folder-delete bookmark],
          react: "`ChevronDownIcon` from `blode-icons-react` is `name: :\"chevron-down\", library: :blode`; the " \
                 "filled twin is `library: :blode_filled`.",
          blurb: "Matthew Blode's icons in matched outline and filled pairs on a 24-unit grid."
        )
      ].freeze

      # The set behind a page slug.
      def self.find(slug) = ALL.find { |set| set.slug == slug }
    end
  end
end
