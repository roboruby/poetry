# frozen_string_literal: true

require "yaml"
require "date"

module Poetry
  module Generators
    # Which editors a generator wires. Poetry never assumes one: the list
    # comes from the first of these that has an answer.
    #
    # 1. `--editor claude cursor` (or `--editor none`): what was asked for.
    # 2. The `editors:` list in config/poetry_components.yml: what an
    #    earlier run wired, so an upgrade keeps exactly those.
    # 3. What can be seen: the agent running the generator names itself in
    #    its shell (Claude Code sets CLAUDECODE, Cursor's agent
    #    CURSOR_AGENT), and an editor in use leaves files of its own in the
    #    repository.
    # 4. A question, when a person is at the terminal.
    # 5. The generator's own fallback: everything for `poetry:editor`,
    #    which was run on purpose, and nothing for `poetry:install`.
    #
    # Whatever is chosen is written back to the manifest.
    module EditorChoice
      # The editors Poetry has files for.
      EDITORS = %w[claude cursor vscode].freeze
      # Where the choice is remembered.
      MANIFEST = "config/poetry_components.yml"
      # How each editor shows itself: variables its shell sets, and files
      # of its own in the repository. Poetry's own files (the skills under
      # .claude/skills) are not on the list, or an install would find the
      # editor it wired the last time.
      SIGNS = {
        "claude" => { env: %w[CLAUDECODE],
                      paths: %w[CLAUDE.md .claude/settings.json .claude/settings.local.json .claude/commands
                                .claude/agents] },
        "cursor" => { env: %w[CURSOR_AGENT CURSOR_TRACE_ID], paths: %w[.cursor .cursorrules] },
        "vscode" => { env: [], term: "vscode", paths: %w[.vscode] }
      }.freeze

      class << self
        # The environment that is read for an agent's own variables: ENV,
        # unless a test names another.
        attr_writer :environment

        # The environment that is read: ENV, unless a test named another.
        #
        # @return [#[]] the environment in use
        def environment
          @environment || ENV
        end
      end

      # The editors to wire, chosen once per run and remembered.
      #
      # @param otherwise [Array<String>] the generator's fallback when nothing
      #   is asked for, remembered or seen, and nobody can be asked
      # @return [Array<String>]
      def editor_choice(otherwise:)
        @editor_choice ||= begin
          chosen, how = named_editors || remembered_editors || seen_editors || asked_editors ||
                        [otherwise, "nothing said which, so #{otherwise.empty? ? "none" : "all of them"}"]
          say_status :editors, "#{chosen.empty? ? "none" : chosen.join(", ")} (#{how})", :cyan
          remember_editors(chosen)
          chosen
        end
      end

      private

      # The --editor option: names, commas or spaces between them; "none"
      # and "all" are the two words that are not names.
      def named_editors
        asked = Array(options[:editor]).flat_map { |name| name.to_s.downcase.split(",") }.map(&:strip)
                                       .reject(&:empty?)
        return nil if asked.empty?

        [named(asked), "--editor"]
      end

      # A list of names as editors, or an error that says which are known.
      def named(names)
        return [] if names == ["none"]
        return EDITORS.dup if names == ["all"]

        unknown = names - EDITORS
        return names.uniq if unknown.empty?

        raise Thor::Error, "poetry: no editor called #{unknown.join(", ")} - choose from #{EDITORS.join(", ")}, " \
                           "all or none"
      end

      # What an earlier run wrote down.
      def remembered_editors
        listed = manifest_data["editors"]
        listed.is_a?(Array) ? [listed.map(&:to_s) & EDITORS, "remembered in #{MANIFEST}"] : nil
      end

      # The editors whose signs are here, each with the sign that gave it away.
      def seen_editors
        seen = SIGNS.filter_map do |editor, signs|
          sign = signs[:env].find { |name| EditorChoice.environment[name].to_s != "" }
          sign ||= "TERM_PROGRAM" if signs[:term] && EditorChoice.environment["TERM_PROGRAM"] == signs[:term]
          sign ||= signs[:paths].find { |path| File.exist?(File.join(destination_root, path)) }
          [editor, sign] if sign
        end
        return nil if seen.empty?

        [seen.map(&:first), "found: #{seen.map { |editor, sign| "#{editor} by #{sign}" }.join(", ")}"]
      end

      # One question, and only to a person: a generator an agent or a
      # script runs has no terminal to answer from.
      def asked_editors
        return nil unless $stdin.tty? && $stdout.tty? && !options[:quiet]

        answer = ask("Which editors should Poetry wire (#{EDITORS.join(", ")}, all, none)?", default: "none")
        [named(answer.to_s.downcase.split(/[\s,]+/).reject(&:empty?)), "your answer"]
      end

      # Writes the choice into the manifest, beside whatever it holds.
      def remember_editors(chosen)
        data = manifest_data
        return if data["editors"] == chosen

        create_file MANIFEST, YAML.dump(data.merge("editors" => chosen)), force: true, verbose: false
      end

      # The manifest as a Hash (empty when there is none yet).
      def manifest_data
        path = File.join(destination_root, MANIFEST)
        data = File.exist?(path) ? YAML.safe_load_file(path, permitted_classes: [Date]) : nil
        data.is_a?(Hash) ? data : {}
      end
    end
  end
end
