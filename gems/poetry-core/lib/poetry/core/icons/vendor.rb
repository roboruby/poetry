# frozen_string_literal: true

module Poetry
  module Core
    module Icons
      # The vendor-time pipeline that makes an upstream SVG safe to render
      # `html_safe`: the icon gems' fetch scripts run every file through it,
      # and a host vendoring its own set should too (see the SECURITY note on
      # {Icons}). Render time never parses; this runs once, at vendor time.
      #
      # It keeps only the <svg>'s inner markup (the Icon component owns the
      # wrapper), removes <script>, <foreignObject>, <title>, <desc> and
      # comments, removes <use>/<image> pointing outside the document, strips
      # every `on*` handler, drops clip paths that clip nothing (a rect over
      # the whole canvas, which also repeats element ids on a page), and with
      # `current_color: true` turns every hardcoded fill and stroke colour
      # into `currentColor` so the icon takes the text colour.
      module Vendor
        # Elements removed with their content.
        REMOVED = %w[script foreignObject title desc metadata].freeze
        # Elements that may reference another document.
        HREF_ELEMENTS = %w[use image].freeze
        # Paint values left as they are by `current_color: true`.
        KEPT_PAINT = %w[none currentColor transparent inherit].freeze

        module_function

        # The sanitized inner markup of one SVG, on a single line.
        #
        # @param svg_source [String] a whole upstream SVG file
        # @param current_color [Boolean] rewrite hardcoded fill and stroke
        #   colours to currentColor
        # @return [String] the inner markup, no newlines or tabs
        # @raise [ArgumentError] when the source has no <svg> root
        def inner_markup(svg_source, current_color: false)
          require "nokogiri"
          root = Nokogiri::XML(svg_source, &:noblanks).root
          raise ArgumentError, "not an svg" unless root&.name == "svg"

          root.xpath("//comment()").each(&:remove)
          root.css(REMOVED.join(", ")).each(&:remove)
          strip_external_hrefs(root)
          strip_handlers(root)
          drop_canvas_clips(root, root["viewBox"])
          repaint(root) if current_color
          root.children.map { |node| node.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML) }
              .join.gsub(/\s*[\r\n\t]\s*/, " ").gsub(/>\s+</, "><").strip
        end

        # The files of a GitHub repository at one commit whose paths match,
        # read from its tarball. Pin a commit SHA, never a tag or branch: the
        # same call must return the same bytes forever.
        #
        # @param repository [String] "owner/name"
        # @param commit [String] a full 40-character commit SHA
        # @param pattern [Regexp] matched against each path inside the repository
        # @return [Hash{String => String}] path => content, for regular files
        # @raise [ArgumentError] when commit is not a full SHA
        # @raise [RuntimeError] when the download fails
        def github_files(repository, commit, pattern)
          raise ArgumentError, "pin a full commit SHA, not #{commit.inspect}" unless commit.match?(/\A\h{40}\z/)

          require "net/http"
          require "rubygems/package"
          require "zlib"
          require "stringio"
          response = Net::HTTP.get_response(URI("https://codeload.github.com/#{repository}/tar.gz/#{commit}"))
          raise "download failed for #{repository}@#{commit}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          files = {}
          Gem::Package::TarReader.new(Zlib::GzipReader.new(StringIO.new(response.body))) do |tar|
            tar.each do |entry|
              path = entry.full_name.split("/", 2).last.to_s
              files[path] = entry.read.force_encoding(Encoding::UTF_8) if entry.file? && path.match?(pattern)
            end
          end
          files
        end

        # A packed set file's text: one `name\tmarkup` line per icon, sorted.
        #
        # @param icons [Hash{String => String}] name => inner markup
        # @return [String]
        # @raise [ArgumentError] for a name outside {NAME_FORMAT} or markup
        #   with a line break or tab in it
        def packed(icons)
          icons.sort.map do |name, markup|
            raise ArgumentError, "bad icon name #{name.inspect}" unless name.match?(NAME_FORMAT)
            raise ArgumentError, "#{name}: markup spans lines" if markup.match?(/[\r\n\t]/)

            "#{name}\t#{markup}\n"
          end.join
        end

        # Removes <use>/<image> whose href leaves the document.
        def strip_external_hrefs(root)
          HREF_ELEMENTS.each do |element|
            root.css(element).each do |node|
              href = node["href"] || node["xlink:href"]
              node.remove if href && !href.start_with?("#")
            end
          end
        end

        # Removes every on* attribute.
        def strip_handlers(root)
          root.traverse do |node|
            next unless node.element?

            node.attribute_nodes.each { |attribute| attribute.remove if attribute.name.downcase.start_with?("on") }
          end
        end

        # Removes clip paths made of one untransformed rect covering the
        # canvas, the references to them, and the groups left bare.
        def drop_canvas_clips(root, view_box)
          _, _, width, height = view_box.to_s.split(/[\s,]+/)
          root.css("clipPath").each do |clip|
            rects = clip.element_children
            next unless rects.size == 1 && rects.first.name == "rect" && clip["transform"].nil?

            rect = rects.first
            next unless rect["x"].to_f.zero? && rect["y"].to_f.zero? && rect["transform"].nil? &&
                        rect["width"] == width && rect["height"] == height

            id = clip["id"]
            root.css(%([clip-path="url(##{id})"])).each do |node|
              node.remove_attribute("clip-path")
              node.replace(node.children) if node.name == "g" && node.attribute_nodes.empty?
            end
            parent = clip.parent
            clip.remove
            parent.remove if parent.name == "defs" && parent.element_children.empty?
          end
        end

        # Every hardcoded fill and stroke colour becomes currentColor.
        def repaint(root)
          root.traverse do |node|
            next unless node.element?

            %w[fill stroke].each do |attribute|
              value = node[attribute]
              next if value.nil? || KEPT_PAINT.include?(value) || value.start_with?("url(")

              node[attribute] = "currentColor"
            end
          end
        end

        private_class_method :strip_external_hrefs, :strip_handlers, :drop_canvas_clips, :repaint
      end
    end
  end
end
