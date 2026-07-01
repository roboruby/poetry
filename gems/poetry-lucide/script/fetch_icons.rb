# frozen_string_literal: true

# Vendors the Lucide icon set at a PINNED COMMIT SHA (never a mutable tag -
# the supply-chain stance/): downloads the upstream tarball,
# sanitizes every SVG, and writes each icon's INNER markup to icons/<name>.svg
# (the Icon component owns the <svg> wrapper). Run from the gem root:
#
#   bundle exec ruby script/fetch_icons.rb
#
# Sanitization strips every dangerous construct from each SVG:
# <script>, <foreignObject>, <use>/<image> with external
# hrefs, and every on* handler attribute. Lucide is trusted-ish upstream;
# the pipeline assumes it isn't.

require "net/http"
require "rubygems/package"
require "zlib"
require "stringio"
require "nokogiri"
require "fileutils"

module PoetryLucide
  class Fetcher
    # lucide-icons/lucide v1.23.0 (2026) - update deliberately, with a diff.
    PINNED_COMMIT = "c67c9bdbfb43b0ecd69b52d37aeb4ab2d5386271"
    TARBALL = "https://codeload.github.com/lucide-icons/lucide/tar.gz/#{PINNED_COMMIT}".freeze

    FORBIDDEN_ELEMENTS = %w[script foreignObject].freeze
    HREF_ELEMENTS = %w[use image].freeze

    def initialize(dest: File.expand_path("../icons", __dir__))
      @dest = dest
    end

    def run!
      icons = extract_icons(download)
      FileUtils.mkdir_p(@dest)
      icons.each { |name, svg| File.write(File.join(@dest, "#{name}.svg"), "#{sanitize(svg)}\n") }
      File.write(File.join(@dest, "VENDORED_COMMIT"), "#{PINNED_COMMIT}\n")
      puts "vendored #{icons.size} icons at #{PINNED_COMMIT[0, 12]} -> #{@dest}"
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

    def extract_icons(tarball)
      icons = {}
      tar = Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(tarball)))
      tar.each do |entry|
        next unless entry.file? && entry.full_name.match?(%r{\A[^/]+/icons/[a-z0-9-]+\.svg\z})

        name = File.basename(entry.full_name, ".svg")
        icons[name] = entry.read
      end
      icons
    end
  end
end

PoetryLucide::Fetcher.new.run! if $PROGRAM_NAME == __FILE__
