# frozen_string_literal: true

require "tmpdir"

module Poetry
  module Docs
    # The docs stylesheet for a host whose own pages wear the docs layout
    # (Poetry::Docs::HostLayout). The engine ships its stylesheet built
    # from its own files, so a class only a host's view uses has no rule
    # in it. This builds the same stylesheet again, from the engine's own
    # Tailwind entry, with the host's folders added as sources, and writes
    # it into the host's builds under the name the host chose:
    #
    #   # config/initializers/poetry_docs.rb
    #   config.stylesheet = "poetry_docs_host"
    #   config.stylesheet_sources = [ "app/views/community" ]
    #
    #   bin/rails poetry_docs:css:host
    #
    # The layouts then link the host's stylesheet in the engine's place.
    # The host bundles tailwindcss-ruby (tailwindcss-rails brings it).
    module HostStylesheet
      module_function

      # The Tailwind entry: the engine's own, then the host's sources.
      #
      # @param sources [Array<String>] folders or files, from +root+
      # @param root [Pathname, String] the host's root
      # @return [String]
      def entry(sources, root:)
        engine = Poetry::Docs.root.join("tailwind/application.css")
        ([ %(@import "#{engine}";) ] + sources.map { |source| %(@source "#{File.expand_path(source, root)}";) }).join("\n") + "\n"
      end

      # Builds the stylesheet into <root>/app/assets/builds/<name>.css.
      #
      # @param root [Pathname, String] the host's root
      # @param name [String] the stylesheet's name, never the engine's own
      # @param sources [Array<String>] the host's folders, from +root+
      # @return [Pathname] the file written
      # @raise [ArgumentError] when no source is named, or the name is the engine's
      # @raise [Poetry::Docs::HostStylesheet::Error] when the build fails
      def build(root:, name: Poetry::Docs.config.stylesheet, sources: Poetry::Docs.config.stylesheet_sources)
        raise ArgumentError, "name the host's folders in config.stylesheet_sources" if sources.empty?
        if name == "poetry_docs"
          raise ArgumentError, "give the host's stylesheet its own name (config.stylesheet = \"poetry_docs_host\"): " \
                               "poetry_docs is the engine's"
        end
        unless Poetry::Docs.root.join("tailwind/application.css").file?
          raise Error, "the engine's Tailwind sources are not in this install: take poetry-docs from its repository"
        end
        require "tailwindcss/ruby"

        output = Pathname.new(root).join("app/assets/builds/#{name}.css")
        FileUtils.mkdir_p(output.dirname)
        Dir.mktmpdir("poetry-docs-host-css") do |dir|
          input = File.join(dir, "#{name}.css")
          File.write(input, entry(sources, root: root))
          ok = system(Tailwindcss::Ruby.executable, "-i", input, "-o", output.to_s, "--minify",
                      out: File::NULL, err: File::NULL)
          raise Error, "the Tailwind build of #{name}.css failed" unless ok
        end
        output
      end

      # A build that failed.
      class Error < StandardError; end
    end
  end
end
