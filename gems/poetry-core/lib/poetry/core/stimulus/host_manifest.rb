# frozen_string_literal: true

require "json"

module Poetry
  module Core
    module Stimulus
      # The host application's controllers manifest: the same
      # config/controllers_manifest.json a gem commits, generated from the
      # app's own Stimulus controllers by a static read of their sources
      # (`bin/rails poetry:stimulus:manifest`). Registered at boot, it makes
      # a host controller validate exactly like a gem's: `use_stimulus`
      # checks its values, targets, actions and events at class load,
      # `poetry check` validates its wiring in templates, and the registry's
      # controllers section carries its API to llms.txt and the MCP server.
      #
      # An entry is complete or absent. A controller that extends another
      # host controller (a relative import) or a poetry controller (an
      # `@poetry/controllers/...` import) merges its parent's surface
      # child-first, as the gem generator does; a parent the reader cannot
      # resolve (a library base class) yields no entry, and the task names
      # it - unvalidated as today, never a partial entry that lies. The
      # hand-written manifest is the escape hatch: the same file.
      #
      # The reader covers the shapes Stimulus controllers are written in:
      # `static targets = [...]`, `static values = { name: Type }` and the
      # `{ type:, default: }` form, `static classes`, `static events` (the
      # poetry convention for dispatched events), and the class body's own
      # methods (lifecycle included, private `#name` and accessors
      # excluded). Computed statics are not read.
      #
      # @example
      #   result = Poetry::Core::Stimulus::HostManifest.generate!(root: Rails.root)
      #   result.skipped # => [#<Skip identifier="fancy" reason="extends SomeLib ...">]
      #
      # @api private
      module HostManifest
        RELATIVE_PATH = "config/controllers_manifest.json"
        CONTROLLERS_DIR = "app/javascript/controllers"
        STIMULUS_PACKAGE = "@hotwired/stimulus"
        POETRY_IMPORT = %r{\A@poetry/controllers/(?:core/)?([\w-]+?)(?:_controller)?\z}
        KEYWORDS = %w[if for while switch catch function return else do try with].freeze
        # A method definition line at class-body depth (a trailing comment allowed).
        METHOD_LINE = %r{\A\s*(?:async\s+)?([A-Za-z_$][\w$]*)\s*\([^)]*\)\s*\{\s*(?://.*)?\z}

        # One controller the reader could not describe, and why.
        Skip = Struct.new(:identifier, :reason, keyword_init: true) do
          def to_s = "#{identifier}: #{reason}"
        end

        # The read of one app: identifier => definition (`definitions`), plus the skips.
        Result = Struct.new(:definitions, :skipped, :path, keyword_init: true)

        # Raised while resolving a parent that cannot be read.
        class Unresolved < StandardError; end

        module_function

        # Reads every `*_controller.js` under the app's controllers
        # directory.
        #
        # @param root [String, Pathname] the app root
        # @return [Result]
        def scan(root:)
          root = Pathname.new(root)
          dir = root.join(CONTROLLERS_DIR)
          definitions = {}
          skipped = []
          Dir.glob(dir.join("**/*_controller.js").to_s).each do |file|
            identifier = identifier_for(Pathname.new(file).relative_path_from(dir).to_s)
            definitions[identifier] = resolve(file, [])
          rescue Unresolved => e
            skipped << Skip.new(identifier: identifier, reason: e.message)
          end
          Result.new(definitions: definitions, skipped: skipped, path: root.join(RELATIVE_PATH))
        end

        # The Stimulus identifier of a controller file path relative to the
        # controllers directory ("admin/audit_log_controller.js" ->
        # "admin--audit-log").
        #
        # @param relative [String]
        # @return [String]
        def identifier_for(relative)
          relative.delete_suffix(".js").delete_suffix("_controller").tr("_", "-").split("/").join("--")
        end

        # The full definition of one controller file, parents merged in.
        #
        # @param file [String] the controller source path
        # @param seen [Array<String>] the chain so far (cycle guard)
        # @return [Hash] the manifest entry
        # @raise [Unresolved] for a parent that cannot be read
        def resolve(file, seen)
          raise Unresolved, "extends chain loops through #{file}" if seen.include?(file)

          parsed = parse(File.read(file))
          parent = parent_definition(parsed, file, seen + [file])
          merge(parent, parsed[:definition])
        end

        # The parent's definition: {} for Stimulus's Controller, a merged
        # read for a relative import, the catalog entry for a poetry import.
        def parent_definition(parsed, file, seen)
          name = parsed[:extends]
          return {} if name.nil?

          path = parsed[:imports][name]
          raise Unresolved, "extends #{name}, which is not imported" if path.nil?
          return {} if path == STIMULUS_PACKAGE

          if path.start_with?("./", "../")
            candidate = File.expand_path(path, File.dirname(file))
            candidate += ".js" unless candidate.end_with?(".js")
            raise Unresolved, "extends #{name} from #{path}, which does not exist" unless File.exist?(candidate)

            return resolve(candidate, seen)
          end
          if (match = POETRY_IMPORT.match(path))
            identifier = "poetry--core--#{match[1].tr("_", "-")}"
            definition = Manifest.catalog[identifier]
            if definition.nil?
              raise Unresolved,
                    "extends #{name} from #{path}, but #{identifier} is not in the manifest"
            end

            return definition
          end
          raise Unresolved, "extends #{name} from #{path}, which the reader cannot follow - write this entry by hand"
        end

        # Child-first merge: the child's values win by name, lists are the
        # parent's then the child's, deduplicated.
        def merge(parent, child)
          {
            "targets" => (parent.fetch("targets", []) + child["targets"]).uniq,
            "values" => parent.fetch("values", {}).merge(child["values"]),
            "classes" => (parent.fetch("classes", []) + child["classes"]).uniq,
            "methods" => (parent.fetch("methods", []) + child["methods"]).uniq,
            "events" => (parent.fetch("events", []) + child["events"]).uniq
          }
        end

        # One source file: the class it extends, its imports, and its own
        # surface.
        #
        # @param source [String]
        # @return [Hash] :extends, :imports, :definition
        def parse(source)
          imports = {}
          source.scan(/^\s*import\s+(\w+)\s+from\s+["']([^"']+)["']/) { |name, path| imports[name] = path }
          source.scan(/^\s*import\s+\{([^}]+)\}\s+from\s+["']([^"']+)["']/) do |names, path|
            names.split(",").each { |name| imports[name.strip.split(/\s+as\s+/).last] = path }
          end
          extends = source[/class(?:\s+\w+)?\s+extends\s+([\w.]+)/, 1]
          {
            extends: extends,
            imports: imports,
            definition: {
              "targets" => static_list(source, "targets"),
              "values" => static_values(source),
              "classes" => static_list(source, "classes"),
              "methods" => methods(source),
              "events" => static_list(source, "events")
            }
          }
        end

        def static_list(source, name)
          list = source[/static\s+#{name}\s*=\s*\[([^\]]*)\]/m, 1]
          list ? list.scan(/["']([^"']+)["']/).flatten : []
        end

        # `static values = { ... }`: `name: Type` or `name: { type: Type, default: ... }`.
        def static_values(source)
          start = source.index(/static\s+values\s*=\s*\{/)
          return {} unless start

          body = balanced(source, source.index("{", start))
          split_top_level(body).each_with_object({}) do |entry, values|
            name, spec = entry.split(":", 2).map(&:strip)
            next if name.nil? || spec.nil? || spec.empty?

            values[name] = if spec.start_with?("{")
                             value_spec(spec)
                           else
                             { "type" => spec }
                           end
          end
        end

        def value_spec(spec)
          inner = balanced(spec, 0)
          type = inner[/\btype\s*:\s*(\w+)/, 1]
          default = inner[/\bdefault\s*:\s*(.+)\z/m, 1]&.strip&.sub(/,\s*\z/, "")
          result = { "type" => type }
          if default
            parsed = literal(default)
            result["default"] = parsed unless parsed.equal?(UNPARSED)
          end
          result
        end

        UNPARSED = Object.new.freeze

        # A JavaScript literal as JSON data; UNPARSED when it is not one.
        def literal(text)
          JSON.parse(text.gsub(/'([^']*)'/, '"\1"'))
        rescue JSON::ParserError
          UNPARSED
        end

        # The text inside the braces opening at `open` (the index of "{").
        def balanced(source, open)
          depth = 0
          (open...source.length).each do |i|
            case source[i]
            when "{" then depth += 1
            when "}"
              depth -= 1
              return source[(open + 1)...i] if depth.zero?
            end
          end
          source[(open + 1)..]
        end

        def split_top_level(body)
          parts = []
          current = +""
          depth = 0
          body.each_char do |char|
            case char
            when "{", "[", "(" then depth += 1
            when "}", "]", ")" then depth -= 1
            end
            if char == "," && depth.zero?
              parts << current.strip
              current = +""
            else
              current << char
            end
          end
          parts << current.strip
          parts.reject(&:empty?)
        end

        # The class body's own methods: definitions at class-body depth,
        # lifecycle included; keywords, `static`, private `#name`, and
        # accessors excluded (an accessor is not an action).
        def methods(source)
          names = []
          depth = 0
          source.each_line do |line|
            if depth == 1 && (match = METHOD_LINE.match(line))
              name = match[1]
              names << name unless KEYWORDS.include?(name) || name == "constructor"
            end
            depth += line.count("{") - line.count("}")
          end
          names.uniq
        end

        # Writes the manifest for the app.
        #
        # @param root [String, Pathname] the app root
        # @return [Result] with `path` set to the written file
        def generate!(root:)
          result = scan(root: root)
          result.path.dirname.mkpath
          result.path.write(render(result.definitions))
          result
        end

        # The file text for a set of definitions (sorted, pretty JSON).
        def render(definitions)
          "#{JSON.pretty_generate(definitions.sort.to_h)}\n"
        end

        # :missing, :fresh, or :stale against the controller sources.
        #
        # @param root [String, Pathname]
        # @return [Symbol]
        def state(root:)
          path = Pathname.new(root).join(RELATIVE_PATH)
          return :missing unless path.exist?

          path.read == render(scan(root: root).definitions) ? :fresh : :stale
        end
      end
    end
  end
end
