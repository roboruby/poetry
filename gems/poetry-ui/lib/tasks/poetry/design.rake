# frozen_string_literal: true

# Host-side DESIGN.md export (N14 W1): serialize THIS app's poetry design as
# the design-skill ecosystem's shared artifact, so external skills
# (the slop-gate analogue, the design-rule analogue, frontend-design, an external design tool) can read the system the
# app actually ships. Loaded automatically by the engine (lib/tasks).
namespace :poetry do
  namespace :design do
    desc "Export this app's poetry design to DESIGN.md " \
         "(POETRY_DESIGN_PATH overrides the target; POETRY_DESIGN_FORCE=1 overwrites a non-poetry file)"
    task export: :environment do
      path = Pathname.new(ENV["POETRY_DESIGN_PATH"] || Rails.root.join("DESIGN.md"))
      if path.exist? && Poetry::Core::DesignMd.parse(path.read)["theme"].nil? && ENV["POETRY_DESIGN_FORCE"] != "1"
        abort "poetry:design:export: #{path} exists and was not written by poetry - " \
              "set POETRY_DESIGN_PATH to export elsewhere, or POETRY_DESIGN_FORCE=1 to overwrite"
      end

      theme = poetry_design_installed_theme
      registry = YAML.safe_load_file(Poetry::Ui.root.join(Poetry::Core::Registry::RELATIVE_PATH))
      details = Poetry::Ui::Themes.details(theme).merge(
        "components_count" => registry.fetch("components").size,
        "generator" => "bin/rails poetry:design:export"
      )
      doc = Poetry::Core::DesignMd.build(tokens: Poetry::Core::Tokens.load, theme: theme, details: details,
                                         deviations: poetry_design_declared_overrides)
      poetry_design_apply_overrides(doc)
      path.write(Poetry::Core::DesignMd.serialize(doc))

      poetry_design_warn_on_token_drift
      puts "poetry:design:export: wrote #{path} (theme #{theme})"
    end

    # The.cn-* override contract (, the intent-vs-accident
    # model): token-level restyling has a sanctioned channel
    # (poetry:design:import -> design-overrides.css); host CSS that targets
    # theme-owned .cn-* classes is the OTHER channel, and every such
    # override must be declared - dated, reasoned, scoped - under
    # `overrides:` in config/poetry_components.yml. This task reports both
    # directions (undeclared drift AND stale declarations); undeclared
    # findings print a paste-ready declaration. Never silence a finding to
    # skip fixing it - declare only what the design owner confirms.
    desc "Report host CSS overriding theme-owned .cn-* classes against the declared contract " \
         "(config/poetry_components.yml `overrides:`; STRICT=1 exits nonzero on undeclared/invalid)"
    task overrides: :environment do
      scan = Poetry::Core::CSS::OverrideScan.new(
        sources: poetry_design_host_css_sources,
        declarations: poetry_design_declared_overrides
      )

      scan.invalid.each { |message| puts "  INVALID   #{message}" }
      scan.stale.each do |declaration|
        puts "  STALE     overrides[#{declaration.index}] (cn: #{declaration.cn.inspect}) matches no host CSS - " \
             "remove it or fix its `files:` scope"
      end
      scan.undeclared.each do |path, classes|
        puts "  UNDECLARED #{path}: #{classes.join(", ")}"
        puts "    declare it (after confirming intent) in config/poetry_components.yml under overrides:"
        puts scan.snippet_for(path, classes).gsub(/^/, "      ")
      end

      if scan.ok?
        puts "poetry:design:overrides: clean - #{scan.declared_count} declared override(s), " \
             "#{scan.stale.size} stale declaration(s)"
      else
        message = "poetry:design:overrides: #{scan.undeclared.sum { |_, c| c.size }} undeclared .cn-* " \
                  "override(s), #{scan.invalid.size} invalid declaration(s)"
        ENV["STRICT"] == "1" ? abort(message) : puts(message)
      end
    end

    desc "Import a DESIGN.md into token overrides " \
         "(app/assets/tailwind/poetry/design-overrides.css; AA enforced at the door, " \
         "POETRY_DESIGN_FORCE=1 ships failing pairs, POETRY_DESIGN_JSON=1 for a JSON report)"
    task :import, [:path] => :environment do |_task, args|
      source = args[:path] or abort "poetry:design:import: pass the file - bin/rails 'poetry:design:import[path]'"
      abort "poetry:design:import: no such file #{source}" unless File.exist?(source)

      doc = Poetry::Core::DesignMd.parse(File.read(source))
      plan = Poetry::Core::DesignMd::Import.new.plan(doc, force: ENV["POETRY_DESIGN_FORCE"] == "1")

      written = nil
      if plan.any_overrides?
        written = Rails.root.join("app/assets/tailwind/poetry/design-overrides.css")
        written.write(poetry_design_overrides_css(plan, File.basename(source)))
        poetry_design_wire_overrides
      end

      if ENV["POETRY_DESIGN_JSON"] == "1"
        puts JSON.pretty_generate(poetry_design_report_json(plan, written))
      else
        puts poetry_design_report(plan, written)
      end
    end
  end
end

# The declared.cn-* overrides from the host manifest - tolerant
# like every other manifest reader (missing file/key = none declared).
def poetry_design_declared_overrides
  path = Rails.root.join("config/poetry_components.yml")
  # Hosts write `created:` as a bare YAML date - permit it, then normalize
  # to ISO strings so everything downstream (scan, DESIGN.md) is string-typed.
  config = path.exist? ? YAML.safe_load_file(path, permitted_classes: [Date]) : nil
  return [] unless config.is_a?(Hash) && config["overrides"].is_a?(Array)

  config["overrides"].map do |entry|
    entry.is_a?(Hash) ? entry.merge("created" => entry["created"]&.to_s) : entry
  end
end

# Host-owned stylesheet SOURCES: everything the app authors, excluding the
# poetry-vendored set (which legitimately defines cn-*) and compiled output.
def poetry_design_host_css_sources
  root = Rails.root
  sources = {}
  root.glob("app/assets/**/*.css").each do |path|
    relative = path.relative_path_from(root).to_s
    next if relative.start_with?("app/assets/tailwind/poetry/", "app/assets/builds/")

    sources[relative] = path.read
  end
  sources
end

# The installed theme, recovered from the slot bytes themselves (the
# installer vendors the chosen fragment verbatim into the style-default.css
# slot) - "custom" when the slot was hand-edited past recognition.
def poetry_design_installed_theme
  slot = Rails.root.join("app/assets/tailwind/poetry/style-default.css")
  abort "poetry:design:export: no poetry install found (#{slot} missing) - run `bin/rails g poetry:install`" \
    unless slot.exist?

  bytes = slot.read
  Poetry::Ui::Themes.names.find { |name| Poetry::Ui.root.join("themes/#{name}.css").read == bytes } || "custom"
end

# The vendored tokens.css may have been replaced wholesale (the shadcn
# drop-in contract) - this export reads the gem's DTCG source, so say so
# rather than silently exporting values the app no longer paints.
def poetry_design_warn_on_token_drift
  host_tokens = Rails.root.join("app/assets/tailwind/poetry/tokens.css")
  return unless host_tokens.exist?
  return if host_tokens.read == Poetry::Core.root.join("tokens/tokens.css").read

  puts "poetry:design:export: NOTE - app/assets/tailwind/poetry/tokens.css diverges from the gem " \
       "defaults (drop-in theme or hand edits); this export lists the gem's token values"
end

# Exports must tell the truth AFTER an import: fold the app's
# design-overrides.css (our own generated format) back into the document
# so the exported DESIGN.md carries the values the app actually paints.
def poetry_design_apply_overrides(doc)
  path = Rails.root.join("app/assets/tailwind/poetry/design-overrides.css")
  return unless path.exist?

  path.read.scan(/^(:root|\.dark)\s*\{([^}]*)\}/m).each do |selector, body|
    mode = selector == ":root" ? "light" : "dark"
    body.scan(/--([a-z0-9-]+):\s*([^;]+);/).each do |name, value|
      if name == "radius"
        doc["radius"] = value.strip if mode == "light"
      elsif doc["colors"][mode].key?(name) && (color = Poetry::Core::Tokens::Color.parse(value.strip))
        doc["colors"][mode][name] = color
      end
    end
  end
  puts "poetry:design:export: includes app/assets/tailwind/poetry/design-overrides.css values"
end

# The overrides stylesheet: :root carries the imported light values (+
# radius); .dark carries imported dark values plus the poetry-default PINS
# for light-overridden names the source left dark-silent (without them the
# later :root block would also win in dark mode - equal specificity).
def poetry_design_overrides_css(plan, source_name)
  lines = ["/* Generated by `bin/rails poetry:design:import` from #{source_name} - do not edit.",
           "   Loads AFTER the poetry theme imports so these blocks win the cascade;",
           "   re-run the import to regenerate. */", ""]
  lines << ":root {"
  lines << "  --radius: #{plan.radius};" if plan.radius
  plan.overrides["light"].sort.each { |name, color| lines << "  --#{name}: #{color.css};" }
  lines << "}"

  dark = plan.overrides["dark"].sort + plan.pins.sort
  if dark.any?
    lines << "" << ".dark {"
    plan.overrides["dark"].sort.each { |name, color| lines << "  --#{name}: #{color.css};" }
    if plan.pins.any?
      lines << "  /* pinned to the poetry defaults (source had no dark palette) */"
      plan.pins.sort.each { |name, color| lines << "  --#{name}: #{color.css};" }
    end
    lines << "}"
  end
  "#{lines.join("\n")}\n"
end

# Idempotently add the overrides import after the last top-level ./poetry/
# import in the Tailwind entry (later = wins at equal specificity).
def poetry_design_wire_overrides
  entry = Rails.root.join("app/assets/tailwind/application.css")
  import_line = %(@import "./poetry/design-overrides.css";)
  unless entry.exist?
    puts "poetry:design:import: NOTE - no #{entry}; add #{import_line} to your Tailwind entry yourself"
    return
  end

  lines = entry.read.lines
  return if lines.any? { |line| line.start_with?(import_line) }

  last = lines.rindex { |line| line.match?(%r{\A@(?:import|source) "\./poetry/}) }
  if last
    lines.insert(last + 1, "#{import_line}\n")
    entry.write(lines.join)
    puts "poetry:design:import: wired #{import_line} into app/assets/tailwind/application.css"
  else
    puts "poetry:design:import: NOTE - no ./poetry/ imports found in #{entry}; " \
         "add #{import_line} after them yourself"
  end
end

def poetry_design_report(plan, written)
  out = []
  plan.overrides.each do |mode, colors|
    next if colors.empty?

    out << ("  applied (#{mode}): " + colors.sort.map { |name, color| "#{name} #{color.css}" }.join(", "))
  end
  out << "  radius: #{plan.radius}" if plan.radius
  out << "  pinned (dark, poetry defaults): #{plan.pins.keys.sort.join(", ")}" if plan.pins.any?
  if plan.contrast.any?
    out << "  contrast (merged set, AA floor):"
    plan.contrast.each { |result| out << "    #{result}" }
  end
  if plan.dropped.any?
    out << "  dropped (never guessed):"
    plan.dropped.each { |drop| out << "    #{drop.name}: #{drop.reason}" }
  end
  out << "  #{plan.typography_note}" if plan.typography_note
  out << if written
           "wrote #{written.relative_path_from(Rails.root)}"
         else
           "no overrides written (nothing importable survived the gate)"
         end
  out.join("\n")
end

def poetry_design_report_json(plan, written)
  {
    "applied" => plan.applied.map do |a|
      { "role" => a.role, "from" => a.from, "mode" => a.mode, "css" => a.color.css }
    end,
    "pins" => plan.pins.transform_values(&:css),
    "radius" => plan.radius,
    "contrast" => plan.contrast.map do |r|
      { "mode" => r.mode, "pair" => r.label, "ratio" => r.ratio.round(2), "pass" => r.pass,
        "suggestion" => r.suggestion, "shipped_failing" => r.shipped }.compact
    end,
    "dropped" => plan.dropped.map do |d|
      { "name" => d.name, "value" => d.value, "mode" => d.mode, "reason" => d.reason }.compact
    end,
    "typography_note" => plan.typography_note,
    "written" => written&.relative_path_from(Rails.root)&.to_s
  }.compact
end
