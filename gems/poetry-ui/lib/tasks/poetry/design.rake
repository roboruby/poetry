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
      doc = Poetry::Core::DesignMd.build(tokens: Poetry::Core::Tokens.load, theme: theme, details: details)
      path.write(Poetry::Core::DesignMd.serialize(doc))

      poetry_design_warn_on_token_drift
      puts "poetry:design:export: wrote #{path} (theme #{theme})"
    end
  end
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
