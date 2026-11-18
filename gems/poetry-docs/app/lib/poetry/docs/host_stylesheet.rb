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

      # How many times a stylesheet is built before one that lacks engine
      # rules is kept as it is.
      ATTEMPTS = 3

      # Builds the stylesheet into <root>/app/assets/builds/<name>.css, and
      # holds the result to the engine's own: every rule of the engine's
      # stylesheet has to be in it. Tailwind has been seen to leave a group
      # of theme rules out of a build made on a busy machine (about one in
      # forty, with nothing reported), so a build that lacks any is made
      # again. One that still lacks them after {ATTEMPTS} is kept, with a
      # warning that names what is missing: the difference may be the
      # host's own, and a stylesheet is better than none.
      #
      # @param root [Pathname, String] the host's root
      # @param name [String] the stylesheet's name, never the engine's own
      # @param sources [Array<String>] the host's folders, from +root+
      # @param compiler [#call] builds the entry file into the output file and
      #   answers whether it worked; Tailwind's own, unless a test hands one in
      # @return [Pathname] the file written
      def build(root:, name: Poetry::Docs.config.stylesheet, sources: Poetry::Docs.config.stylesheet_sources,
                compiler: method(:tailwind))
        raise ArgumentError, "name the host's folders in config.stylesheet_sources" if sources.empty?
        if name == "poetry_docs"
          raise ArgumentError, "give the host's stylesheet its own name (config.stylesheet = \"poetry_docs_host\"): " \
                               "poetry_docs is the engine's"
        end
        unless Poetry::Docs.root.join("tailwind/application.css").file?
          raise Error, "the engine's Tailwind sources are not in this install: take poetry-docs from its repository"
        end

        output = Pathname.new(root).join("app/assets/builds/#{name}.css")
        FileUtils.mkdir_p(output.dirname)
        Dir.mktmpdir("poetry-docs-host-css") do |dir|
          input = File.join(dir, "#{name}.css")
          File.write(input, entry(sources, root: root))
          ATTEMPTS.times do |attempt|
            raise Error, "the Tailwind build of #{name}.css failed" unless compiler.call(input, output.to_s)

            lost = lost_rules(output.read)
            break if lost.empty?

            warn "poetry-docs: #{name}.css was built without #{lost.size} of the engine's rules " \
                 "(the first: #{lost.first.join(" {")[0, 90]}) - " \
                 "#{attempt + 1 < ATTEMPTS ? "building it again" : "kept as it is after #{ATTEMPTS} builds"}"
          end
        end
        output
      end

      # The engine's rules a built stylesheet does not have, each as its
      # selector and its declarations. A rule is looked for by one selector
      # at a time, so a build that folded two rules with the same
      # declarations into one still has both.
      #
      # @param css [String] a built stylesheet
      # @param engine [String] the engine's own, the committed build unless given
      # @return [Array<Array(String, String)>] the missing [selector, declarations] pairs
      def lost_rules(css, engine: engine_stylesheet)
        return [] if engine.nil?

        rules(engine) - rules(css)
      end

      # A stylesheet as [selector, declarations] pairs, one per selector of
      # each rule, whatever at-rule the rule sits in.
      def rules(css)
        css.split("}").flat_map do |fragment|
          selectors, declarations = fragment[/[^{}]*\{[^{}]*\z/].to_s.split("{", 2)
          next [] if declarations.nil?

          selectors.split(",").map { |selector| [ selector.strip, declarations.strip ] }
        end.uniq
      end

      # The engine's committed stylesheet, or nil in an install without it.
      def engine_stylesheet
        path = Poetry::Docs.root.join("app/assets/builds/poetry_docs.css")
        path.file? ? path.read : nil
      end

      # Tailwind's own build of an entry file into an output file.
      def tailwind(input, output)
        require "tailwindcss/ruby"
        system(Tailwindcss::Ruby.executable, "-i", input, "-o", output, "--minify", out: File::NULL, err: File::NULL)
      end

      # A build that failed.
      class Error < StandardError; end
    end
  end
end
