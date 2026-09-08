# frozen_string_literal: true

# Host-side poetry check: lint the app's ERB against the committed
# registry + controllers manifest.
# Loaded automatically by the engine (lib/tasks).
namespace :poetry do
  desc "Lint app ERB + icon declarations in app Ruby against the poetry registry " \
       "(glob arg overrides the default sweep; POETRY_CHECK_JSON=1 for JSON)"
  task :check, [:glob] => :environment do |_task, args|
    # The linter parses ERB with herb, which stays out of poetry's runtime
    # dependencies on purpose (hosts never need it to RENDER) - same
    # optional-parser posture as poetry:verify's template gate.
    unless Poetry::Core::CSS::TemplateClasses.available?
      abort "poetry:check: the herb gem is required to parse templates - " \
            "`bin/rails g poetry:install` adds it to your development group " \
            "(or add `gem \"herb\"` to the Gemfile yourself and bundle)"
    end

    # Default sweep: ERB through the template tier, app Ruby through the
    # icon-declaration tier (the FLASH_ICONS pattern lives in .rb).
    patterns = args[:glob] ? [args[:glob]] : ["app/{views,components}/**/*.html.erb", "app/**/*.rb"]
    paths = patterns.flat_map { |pattern| Dir.glob(Rails.root.join(pattern).to_s) }.uniq
    if paths.empty?
      warn "poetry check: no files matched #{patterns.join(", ").inspect}"
      exit 0
    end

    helpers = Poetry::Ui.helper_names
    roots = [Poetry::Ui.root]
    if defined?(Poetry::Charts::ComponentsHelper)
      helpers += Poetry::Charts::ComponentsHelper.public_instance_methods(false)
                                                 .grep(/\Apoetry_/).map(&:to_s)
      # The charts registry must join the catalog, not just the helper
      # names - a name-valid pathless helper reads as a yielding wrapper
      # (the chart yieldless-block false-positive class).
      roots << Poetry::Charts.root
    end
    # The active set's names light up membership validation (the value
    # contract) and the declaration tier; a host without a
    # registered set still checks icon-name shape.
    icon_names = begin
      Poetry::Core::Icons.set.names
    rescue Poetry::Core::Error
      nil
    end
    catalog = Poetry::Core::Check::Catalog.from_registries(roots, helpers: helpers, icon_names: icon_names)
    findings = Poetry::Core::Check::Runner.new(catalog).run(paths)

    # The taste tier: design-slop warnings join the mechanical
    # findings on request - same vocabulary, same JSON/text output. The
    # stock-theme nudge fires only for a FOREIGN DESIGN.md (a brand waiting
    # to be applied) - poetry's own export IS the current state.
    if ENV["POETRY_CHECK_DESIGN"] == "1"
      # DesignLint herb-parses templates - the .rb paths in the sweep are
      # the declaration tier's, not its.
      findings += paths.grep(/\.erb\z/).flat_map { |path| Poetry::Core::DesignLint.lint(File.read(path), file: path) }
      design_md = Rails.root.join("DESIGN.md")
      foreign = design_md.exist? && Poetry::Core::DesignMd.parse(design_md.read)["theme"].nil?
      findings += Poetry::Core::DesignLint.lint_dom(
        doc: nil,
        context: { design_md_present: foreign,
                   overrides_present: Rails.root.join("app/assets/tailwind/poetry/design-overrides.css").exist? }
      )
    end

    if ENV["POETRY_CHECK_JSON"] == "1"
      puts Poetry::Core::Check.to_json(findings)
    else
      puts Poetry::Core::Check.to_text(findings)
    end

    exit 1 if findings.any? { |finding| finding.severity == :error }
  end
end
