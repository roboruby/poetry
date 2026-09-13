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
      # `@poetry/controllers` import) merges its parent's surface
      # child-first, as the gem generator does; a parent the reader cannot
      # resolve (a library base class), or a static the reader cannot read
      # (a computed `static targets`, a spread, a getter), yields no entry,
      # and the task names it - unvalidated as today, never a partial entry
      # that lies. The hand-written entry is the escape hatch: written into
      # the same file for a skipped identifier, it survives regeneration
      # and never trips the staleness gate (only read identifiers are
      # compared).
      #
      # The read: the source is first MASKED - comments, string, template
      # and regex literal contents replaced by spaces, delimiters and
      # newlines kept, so positions line up - and structure (braces, commas,
      # method heads, imports) is read from the mask while literal text
      # (target names, defaults, import paths) is read from the original at
      # the same positions. That is what keeps a `//` comment inside
      # `static values`, a `"{"` in a string, or a regex with braces from
      # corrupting the entry. Methods are the class body's own: lifecycle
      # included, private `#name`, accessors, `static` members and
      # Stimulus's own callbacks (`fooValueChanged`, `barTargetConnected`)
      # excluded, since none of them is an action. `static events` is read
      # only as a literal array; a computed one leaves events unknown
      # (unvalidated), never empty.
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
        # A parent imported from a poetry gem: the file form
        # (`@poetry/controllers/dialog_controller`, with or without the
        # `core/` segment and the `.js`) and the barrel form
        # (`import { DialogController } from "@poetry/controllers"`); the
        # charts and agent gems by their own package names.
        POETRY_PACKAGES = {
          "@poetry/controllers" => "poetry--core--",
          "@poetry/charts" => "poetry--charts--",
          "@poetry/agent" => "poetry--agent--"
        }.freeze
        KEYWORDS = %w[if for while switch catch function return else do try with].freeze
        # Stimulus's own lifecycle callbacks by naming convention: not actions.
        CALLBACK = /(?:ValueChanged|TargetConnected|TargetDisconnected|OutletConnected|OutletDisconnected)\z/
        # A method head at class-body depth: `name(` (async allowed, a
        # generator star allowed) or an arrow-function class field
        # `name = (…) =>` / `name = arg =>`. Getters, setters, `static` and
        # `#private` members never match: their first token is not the
        # name followed by `(` or `=`.
        METHOD_HEAD = /\A\s*(?:async\s+)?\*?\s*([A-Za-z_$][\w$]*)\s*\(/
        ARROW_FIELD = /\A\s*([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:\([^)]*\)|[A-Za-z_$][\w$]*)\s*=>/
        # A regex literal may start only after one of these (or at the
        # start of the file / after a keyword); otherwise `/` divides.
        REGEX_PRECEDERS = "(,=:[!&|?{};+-*%<>~^".chars.freeze
        REGEX_KEYWORDS = %w[return typeof instanceof in of new delete void throw case do else].freeze

        # One controller the reader could not describe, and why.
        Skip = Struct.new(:identifier, :reason, keyword_init: true) do
          def to_s = "#{identifier}: #{reason}"
        end

        # The read of one app: identifier => definition (`definitions`), plus the skips.
        Result = Struct.new(:definitions, :skipped, :path, keyword_init: true)

        # Raised while resolving a parent that cannot be read, or a static
        # the reader cannot read completely.
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
          Dir.glob(dir.join("**/*_controller.js").to_s).sort.each do |file|
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
        # @raise [Unresolved] for a parent or a static that cannot be read
        def resolve(file, seen)
          raise Unresolved, "extends chain loops through #{file}" if seen.include?(file)

          parsed = parse(read(file))
          parent = parent_definition(parsed, file, seen + [file])
          merge(parent, parsed[:definition])
        end

        # The file as UTF-8, invalid bytes scrubbed (a stray byte is not a
        # reason to abort a read).
        def read(file)
          File.read(file, encoding: "UTF-8").scrub(" ").delete_prefix("﻿")
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
            candidate = File.join(candidate.delete_suffix(".js"), "index.js") if !File.exist?(candidate) && File.directory?(candidate.delete_suffix(".js"))
            raise Unresolved, "extends #{name} from #{path}, which does not exist" unless File.exist?(candidate)

            return resolve(candidate, seen)
          end
          if (identifier = poetry_identifier(name, path))
            definition = Manifest.catalog[identifier]
            if definition.nil?
              raise Unresolved,
                    "extends #{name} from #{path}, but #{identifier} is not in the manifest"
            end

            return definition
          end
          raise Unresolved, "extends #{name} from #{path}, which the reader cannot follow - write this entry by hand"
        end

        # The catalog identifier a poetry import names, or nil when the
        # path is not a poetry package.
        def poetry_identifier(name, path)
          package, prefix = POETRY_PACKAGES.find { |pkg, _| path == pkg || path.start_with?("#{pkg}/") }
          return nil unless package

          rest = path.delete_prefix(package).delete_prefix("/").delete_prefix("core/").delete_suffix(".js")
          base = rest.empty? ? name.delete_suffix("Controller").gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase : rest.delete_suffix("_controller")
          prefix + base.tr("_", "-")
        end

        # Child-first merge: the child's values win by name, lists are the
        # parent's then the child's, deduplicated; events stay unknown when
        # neither side declares them.
        def merge(parent, child)
          entry = {
            "targets" => (parent.fetch("targets", []) + child["targets"]).uniq,
            "values" => parent.fetch("values", {}).merge(child["values"]),
            "classes" => (parent.fetch("classes", []) + child["classes"]).uniq,
            "methods" => (parent.fetch("methods", []) + child["methods"]).uniq
          }
          events = [parent["events"], child["events"]].compact
          entry["events"] = events.flatten.uniq unless events.empty?
          entry
        end

        # One source file: the class it extends, its imports, and its own
        # surface.
        #
        # @param source [String]
        # @return [Hash] :extends, :imports, :definition
        # @raise [Unresolved] when the file holds no class, or a static is
        #   not a readable literal
        def parse(source)
          masked = mask(source)
          clean = mask(source, strings: :keep)
          raise Unresolved, "no class in the file (a re-export or a helper module)" unless masked.match?(/\bclass\b/)
          if (getter = masked[/\bstatic\s+get\s+(targets|values|classes)\b/, 1])
            raise Unresolved, "static #{getter} is a getter, not a literal - write this entry by hand"
          end

          definition = {
            "targets" => static_list(clean, masked, "targets"),
            "values" => static_values(clean, masked),
            "classes" => static_list(clean, masked, "classes"),
            "methods" => methods(masked)
          }
          events = static_list(clean, masked, "events", computed: :unknown)
          definition["events"] = events unless events == :unknown
          {
            extends: extends_name(masked),
            imports: imports(clean, masked),
            definition: definition
          }
        end

        # The parent class name: the default export's when there is one (a
        # helper class above it does not count), else the first class's.
        def extends_name(masked)
          masked[/\bexport\s+default\s+class\b(?:\s+[\w$]+)?\s+extends\s+([\w$.]+)/, 1] ||
            masked[/\bclass\b(?:\s+[\w$]+)?\s+extends\s+([\w$.]+)/, 1]
        end

        # The source with every comment and every string, template and
        # regex literal's contents replaced by spaces - same length, same
        # newlines, delimiters kept - so structure can be read without
        # literal text interfering, and literal text read back from the
        # original at the same positions.
        def mask(source, strings: :blank)
          keep = strings == :keep
          out = source.dup
          i = 0
          n = source.length
          last = nil # the last significant character, for the regex/division call
          while i < n
            c = source[i]
            d = source[i + 1]
            if c == "/" && d == "/"
              j = source.index("\n", i) || n
              blank(out, i, j)
              i = j
            elsif c == "/" && d == "*"
              j = source.index("*/", i + 2)
              j = j ? j + 2 : n
              blank(out, i, j)
              i = j
            elsif c == '"' || c == "'"
              j = literal_end(source, i, c)
              blank(out, i + 1, j - 1) if !keep && j - 1 > i + 1
              last = c
              i = j
            elsif c == "`"
              j = template_end(source, i)
              blank(out, i + 1, j - 1) if !keep && j - 1 > i + 1
              last = c
              i = j
            elsif c == "/" && regex_start?(last, source, i)
              j = literal_end(source, i, "/", regex: true)
              blank(out, i + 1, j - 1) if !keep && j - 1 > i + 1
              last = "/"
              i = j
            else
              last = c unless c.match?(/\s/)
              i += 1
            end
          end
          out
        end

        def blank(out, from, to)
          (from...to).each { |k| out[k] = " " unless out[k] == "\n" }
        end

        # The index just past the closing delimiter (backslash escapes
        # honoured; an unterminated literal runs to the line end).
        def literal_end(source, from, delimiter, regex: false)
          i = from + 1
          in_class = false
          while i < source.length
            c = source[i]
            case c
            when "\\" then i += 2
            when "\n" then return i
            else
              if regex
                in_class = true if c == "["
                in_class = false if c == "]"
                return i + 1 if c == delimiter && !in_class
              elsif c == delimiter
                return i + 1
              end
              i += 1
            end
          end
          source.length
        end

        # The index just past a template literal's closing backtick; `${…}`
        # holes are blanked with the rest (targets never live in one).
        def template_end(source, from)
          i = from + 1
          while i < source.length
            case source[i]
            when "\\" then i += 2
            when "`" then return i + 1
            else i += 1
            end
          end
          source.length
        end

        # Whether a `/` at `i` starts a regex literal: it does after an
        # operator, an opening bracket, a separator, a keyword, or at the
        # start; it divides after a value.
        def regex_start?(last, source, i)
          return true if last.nil? || REGEX_PRECEDERS.include?(last)
          return false unless last.match?(/[\w$]/)

          word = source[0...i].rstrip[/[\w$]+\z/]
          REGEX_KEYWORDS.include?(word)
        end

        # `static <name> = [...]` read as a literal array of strings; a
        # computed, spread or template entry raises (or answers `computed`
        # when the caller accepts an unknown list). Absent means [] for
        # targets/classes and `computed` (unknown) for events.
        def static_list(source, masked, name, computed: nil)
          match = masked.match(/\bstatic\s+#{name}\s*=\s*/)
          return (name == "events" ? computed : []) unless match

          open = match.end(0)
          unless masked[open] == "["
            return computed if computed
            raise Unresolved, "static #{name} is computed, not a literal array - write this entry by hand"
          end

          close = closing(masked, open, "[", "]")
          inner_masked = masked[(open + 1)...close]
          inner = source[(open + 1)...close]
          if inner_masked.match?(/\.\.\.|`/)
            return computed if computed
            raise Unresolved, "static #{name} holds a spread or a template entry - write this entry by hand"
          end

          strings(inner_masked, inner)
        end

        # The string literals of a masked slice, read from the original.
        def strings(masked_slice, original_slice)
          found = []
          position = 0
          while (start = masked_slice.index(/(["']) *\1/, position))
            finish = masked_slice.index(masked_slice[start], start + 1)
            found << original_slice[(start + 1)...finish]
            position = finish + 1
          end
          found.reject(&:empty?)
        end

        # `static values = { ... }`: `name: Type` or `name: { type: Type, default: ... }`.
        def static_values(source, masked)
          match = masked.match(/\bstatic\s+values\s*=\s*/)
          return {} unless match

          open = match.end(0)
          raise Unresolved, "static values is computed, not an object literal - write this entry by hand" unless masked[open] == "{"

          close = closing(masked, open, "{", "}")
          entries(masked[(open + 1)...close], source[(open + 1)...close]).each_with_object({}) do |(name, spec_masked, spec), values|
            values[name] = if spec_masked.lstrip.start_with?("{")
                             value_spec(spec_masked, spec)
                           else
                             { "type" => spec.strip }
                           end
          end
        end

        # The top-level `name: spec` entries of an object literal body, as
        # [name, masked spec, original spec] triples.
        def entries(body_masked, body)
          triples = []
          start = 0
          depth = 0
          body_masked.each_char.with_index do |char, i|
            case char
            when "{", "[", "(" then depth += 1
            when "}", "]", ")" then depth -= 1
            when ","
              next unless depth.zero?

              triples << entry(body_masked[start...i], body[start...i])
              start = i + 1
            end
          end
          triples << entry(body_masked[start..], body[start..])
          triples.compact
        end

        def entry(masked_text, text)
          colon = masked_text.index(":")
          return nil if colon.nil?

          name = masked_text[0...colon].strip
          return nil if name.empty? || !name.match?(/\A[\w$]+\z/)

          [name, masked_text[(colon + 1)..], text[(colon + 1)..]]
        end

        def value_spec(spec_masked, spec)
          open = spec_masked.index("{")
          close = closing(spec_masked, open, "{", "}")
          props = entries(spec_masked[(open + 1)...close], spec[(open + 1)...close]).to_h { |name, _, text| [name, text.strip] }
          result = { "type" => props["type"]&.[](/\w+/) }
          if props.key?("default")
            parsed = literal(props["default"])
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

        # The index of the bracket closing the one at `open` (the source is
        # masked, so brackets inside literals do not count).
        def closing(masked, open, opener, closer)
          depth = 0
          (open...masked.length).each do |i|
            case masked[i]
            when opener then depth += 1
            when closer
              depth -= 1
              return i if depth.zero?
            end
          end
          masked.length
        end

        # The import bindings: local name => package path, read from the
        # original lines the mask shows as imports (paths are strings).
        def imports(source, masked)
          bindings = {}
          masked.each_line.with_index do |line, index|
            next unless line.match?(/\A\s*import\b/)

            original = source.lines[index]
            path = original[/from\s+["']([^"']+)["']/, 1]
            next unless path

            clause = original[/\Aimport\s+(.+?)\s+from/m, 1].to_s
            names = clause[/\{([^}]*)\}/, 1].to_s.split(",").map { |n| n.strip.split(/\s+as\s+/).last }.reject(&:empty?)
            default = clause.sub(/\{[^}]*\}/, "").delete(",").strip
            names << default unless default.empty? || default.start_with?("*")
            names.each { |n| bindings[n] = path }
          end
          bindings
        end

        # The class body's own methods, from the masked source: heads at
        # class-body depth, lifecycle included; keywords, the constructor,
        # accessors, `static` members, private `#name` and Stimulus's own
        # callbacks excluded.
        def methods(masked)
          names = []
          depth = 0
          masked.each_line do |line|
            if depth == 1 && (match = METHOD_HEAD.match(line) || ARROW_FIELD.match(line))
              name = match[1]
              names << name unless KEYWORDS.include?(name) || name == "constructor" || name.match?(CALLBACK)
            end
            depth += line.count("{") - line.count("}")
          end
          names.uniq
        end

        # Writes the manifest for the app: every entry the read produced,
        # plus every existing entry for an identifier the read did not
        # (the hand-written escape hatch, kept verbatim).
        #
        # @param root [String, Pathname] the app root
        # @return [Result] with `path` set to the written file
        def generate!(root:)
          result = scan(root: root)
          kept = (existing(result.path) || {}).reject { |identifier, _| result.definitions.key?(identifier) }
          result.path.dirname.mkpath
          result.path.write(render(kept.merge(result.definitions)))
          result
        end

        # The file text for a set of definitions (sorted, pretty JSON).
        def render(definitions)
          "#{JSON.pretty_generate(definitions.sort.to_h)}\n"
        end

        # :missing, :fresh, or :stale against the controller sources: the
        # read identifiers must match the file's entries for them (data,
        # not bytes); hand-written entries for other identifiers are the
        # host's and never count.
        #
        # @param root [String, Pathname]
        # @return [Symbol]
        def state(root:)
          path = Pathname.new(root).join(RELATIVE_PATH)
          return :missing unless path.exist?

          committed = existing(path)
          return :stale if committed.nil?

          read = JSON.parse(JSON.generate(scan(root: root).definitions))
          committed.slice(*read.keys) == read ? :fresh : :stale
        end

        # The committed file's entries, {} when absent, nil when unreadable.
        def existing(path)
          return {} unless path.exist?

          parsed = JSON.parse(path.read)
          parsed.is_a?(Hash) ? parsed : nil
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
