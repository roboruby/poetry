# frozen_string_literal: true

# Vendors the Lucide icon set at a PINNED COMMIT SHA (never a mutable tag -
# the supply-chain stance): downloads the upstream tarball,
# sanitizes every SVG, and writes each icon's INNER markup to icons/<name>.svg
# (the Icon component owns the <svg> wrapper), plus icons/aliases.json: the
# old names Lucide renamed, each to its current name, from the icons' own
# metadata. Run from the gem root:
#
#   bundle exec ruby script/fetch_icons.rb
#
# Sanitization: strips <script>, <foreignObject>, <use>/<image> with external
# hrefs, and every on* handler attribute. Lucide is trusted-ish upstream;
# the pipeline assumes it isn't.

require "net/http"
require "rubygems/package"
require "zlib"
require "stringio"
require "nokogiri"
require "fileutils"
require "json"

module PoetryLucide
  class Fetcher
    # lucide-icons/lucide 1.57.0 (2026-10-14) - update deliberately, with a diff.
    PINNED_COMMIT = "dab294f313897bacaa968b725b3259fa37c17bd1"
    TARBALL = "https://codeload.github.com/lucide-icons/lucide/tar.gz/#{PINNED_COMMIT}".freeze

    FORBIDDEN_ELEMENTS = %w[script foreignObject].freeze
    HREF_ELEMENTS = %w[use image].freeze

    def initialize(dest: File.expand_path("../icons", __dir__))
      @dest = dest
    end

    def run!
      icons, metadata = extract_icons(download)
      FileUtils.mkdir_p(@dest)
      # A renamed or removed icon must not linger as a stale file.
      Dir[File.join(@dest, "*.svg")].each { |path| File.delete(path) }
      icons.each { |name, svg| File.write(File.join(@dest, "#{name}.svg"), "#{sanitize(svg)}\n") }
      aliases = aliases_from(metadata, icons.keys)
      File.write(File.join(@dest, "aliases.json"), "#{JSON.pretty_generate(aliases)}\n")
      File.write(File.join(@dest, "VENDORED_COMMIT"), "#{PINNED_COMMIT}\n")
      puts "vendored #{icons.size} icons and #{aliases.size} aliases at #{PINNED_COMMIT[0, 12]} -> #{@dest}"
    end

    # The sanitizer, exposed for the seeded-malicious-SVG test: takes full
    # <svg> source, returns the cleaned INNER markup.
    def sanitize(svg_source)
      doc = Nokogiri::XML(svg_source, &:noblanks)
      root = doc.root
      raise ArgumentError, "not an svg" unless root&.name == "svg"

      root.css(FORBIDDEN_ELEMENTS.join(", ")).each(&:remove)
      strip_external_hrefs(root)
      strip_handlers(root)
      root.children.map(&:to_xml).join.strip
    end

    private

    def strip_external_hrefs(root)
      HREF_ELEMENTS.each do |element|
        root.css(element).each do |node|
          href = node["href"] || node["xlink:href"]
          node.remove if href && !href.start_with?("#")
        end
      end
    end

    def strip_handlers(root)
      root.traverse do |node|
        next unless node.element?

        node.attribute_nodes.each { |attr| attr.remove if attr.name.downcase.start_with?("on") }
      end
    end

    def download
      uri = URI(TARBALL)
      response = Net::HTTP.get_response(uri)
      raise "download failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    # name => SVG source, and name => the icon's JSON metadata.
    def extract_icons(tarball)
      icons = {}
      metadata = {}
      tar = Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(tarball)))
      tar.each do |entry|
        next unless entry.file? && entry.full_name.match?(%r{\A[^/]+/icons/[a-z0-9-]+\.(svg|json)\z})

        name = File.basename(entry.full_name).sub(/\.(svg|json)\z/, "")
        entry.full_name.end_with?(".svg") ? icons[name] = entry.read : metadata[name] = JSON.parse(entry.read)
      end
      [icons, metadata]
    end

    # Old name => current name, from each icon's "aliases" (a string or a
    # { "name" => ... } entry). An alias that is itself a current icon, or
    # names an icon not vendored, is dropped.
    def aliases_from(metadata, names)
      metadata.each_with_object({}) do |(current, data), aliases|
        next unless names.include?(current)

        Array(data["aliases"]).each do |entry|
          old = entry.is_a?(Hash) ? entry["name"] : entry
          aliases[old] = current if old.to_s.match?(/\A[a-z0-9][a-z0-9-]*\z/) && !names.include?(old)
        end
      end.sort.to_h
    end
  end
end

PoetryLucide::Fetcher.new.run! if $PROGRAM_NAME == __FILE__
