# frozen_string_literal: true

# Vendors Solar Icon Set at a PINNED COMMIT SHA (never a mutable tag - the
# supply-chain stance): reads the upstream tarball, runs every SVG through
# poetry-core's Icons::Vendor (inner markup only; <script>, <foreignObject>,
# <title>, handlers and external hrefs removed, hardcoded colours to currentColor),
# and writes one packed file per variant under icons/. Run from the gem root:
#
#   bundle exec ruby script/fetch_icons.rb
#
# Review the diff before committing; never hand-edit icons/.

require "poetry/core"
require "fileutils"

module PoetrySolar
  # Downloads, sanitizes and packs the set.
  class Fetcher
    # saoudi-h/solar-icons main, 2026-10 - update deliberately, with a diff.
    PINNED_COMMIT = "571bcc31d0e600033257285c886842b1ce93bb54"
    REPOSITORY = "saoudi-h/solar-icons"

    # Packed file, the upstream paths it takes (the capture is the
    # icon's name), and whether hardcoded colours become currentColor.
    VARIANTS = [
      ["linear.tsv", %r{\Apackages/core/svgs/[^/]+/Linear/([^/]+)\.svg\z}, true],
      ["bold.tsv", %r{\Apackages/core/svgs/[^/]+/Bold/([^/]+)\.svg\z}, true],
      ["bold-duotone.tsv", %r{\Apackages/core/svgs/[^/]+/BoldDuotone/([^/]+)\.svg\z}, true],
      ["broken.tsv", %r{\Apackages/core/svgs/[^/]+/Broken/([^/]+)\.svg\z}, true],
      ["line-duotone.tsv", %r{\Apackages/core/svgs/[^/]+/LineDuotone/([^/]+)\.svg\z}, true],
      ["outline.tsv", %r{\Apackages/core/svgs/[^/]+/Outline/([^/]+)\.svg\z}, true]
    ].freeze

    def initialize(dest: File.expand_path("../icons", __dir__))
      @dest = dest
    end

    def run!
      pattern = Regexp.union(VARIANTS.map { |_file, source, _repaint| source })
      files = Poetry::Core::Icons::Vendor.github_files(REPOSITORY, PINNED_COMMIT, pattern)
      FileUtils.mkdir_p(@dest)
      VARIANTS.each do |file, source, current_color|
        icons = {}
        # A file already named cleanly wins over one that cleans up to the same name.
        ordered = files.sort_by { |path, _svg| [clean?(File.basename(path, ".svg")) ? 0 : 1, path] }
        ordered.each do |path, svg|
          match = source.match(path) or next
          name = icon_name(match[1])
          next warn("skipped #{path}: #{name} is already taken") if icons.key?(name)

          icons[name] = Poetry::Core::Icons::Vendor.inner_markup(svg, current_color: current_color)
        end
        File.write(File.join(@dest, file), Poetry::Core::Icons::Vendor.packed(icons))
        puts "#{file}: #{icons.size} icons"
      end
      File.write(File.join(@dest, "VENDORED_COMMIT"), "#{PINNED_COMMIT}\n")
      puts "vendored saoudi-h/solar-icons at #{PINNED_COMMIT[0, 12]} -> #{@dest}"
    end

    # An upstream file name as a Poetry icon name: lowercase kebab-case.
    def icon_name(raw)
      name = raw.strip.downcase.gsub("+", "-plus").gsub(/[\s_]+/, "-").gsub(/-{2,}/, "-")
      name.gsub(/[^a-z0-9-]/, "").delete_prefix("-").delete_suffix("-")
    end

    # Whether an upstream file name is already a Poetry icon name.
    def clean?(raw) = icon_name(raw) == raw
  end
end

PoetrySolar::Fetcher.new.run! if $PROGRAM_NAME == __FILE__
