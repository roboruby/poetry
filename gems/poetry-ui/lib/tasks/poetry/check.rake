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
    # optional-parser posture as poetry:verify's template gate. From
    # Rails 8.2 Action View depends on herb, so the bundle has it already.
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

    # Every published registry in the boot (poetry-ui, poetry-charts, any
    # engine on the DSL that committed one, the app's own file): no gem is
    # named. The valid helper set is each registry's component-mapped
    # helpers plus its helpers section (the pathless wrappers, part
    # helpers, value contracts), which the builders keep complete.
    roots = Poetry::Core::Registry.roots
    # The active set's names light up membership validation (the value
    # contract) and the declaration tier; a host without a
    # registered set still checks icon-name shape.
    icon_names = begin
      Poetry::Core::Icons.set.names
    rescue Poetry::Core::Error
      nil
    end
    # The app's own components (`helper :name` on the DSL): their declared
    # helpers join the valid set and their contracts are checked like the
    # gems' - built live from the loaded classes, never a committed file.
    host = Poetry::Core::HostComponents.registry(root: Rails.root)
    # The app's own poetry_* helper METHODS (app/helpers: the adapter
    # poetry:pagination copies in, a wrapper the host wrote) are valid
    # names with contracts of their own - the wiring rules still apply.
    host_helpers = Poetry::Core::HostComponents.helper_methods(root: Rails.root)
    catalog = Poetry::Core::Check::Catalog.from_registries(roots, icon_names: icon_names, host_registry: host,
                                                                  host_helpers: host_helpers)
    # The compile tier: Rails checks an app's views (`bin/rails
    # herb:check` walks the view paths), which leaves the templates that
    # sit beside their components unchecked - the app's own and the ones
    # the gems ship. They compile here in the same posture. A herb older
    # than the gate is written for leaves the tier out and says so, on
    # stderr so the JSON stays whole.
    compile_gap = Poetry::Core::Check::Compile.unavailable
    warn "poetry:check: #{compile_gap} - component templates were not compiled" if compile_gap
    rendering = Poetry::Core::Check::Compile.rendering?
    compile = Poetry::Core::Check::Compile.new(rendering: rendering) unless compile_gap
    # The renderable rule: a component class that declares an option, a
    # style or a slot named `format` defines the reader Rails asks a
    # component for. From Rails 8.2 every render in a view asks, so the
    # finding is an error there and a warning before.
    asks_in_views = ActionView.gem_version >= Gem::Version.new("8.2.0.alpha")
    renderable = Poetry::Core::Check::RenderableReaders.new(severity: asks_in_views ? :error : :warning)
    findings = Poetry::Core::Check::Runner.new(catalog, compile: compile, renderable: renderable)
                                          .run(paths, root: Rails.root)
    findings += compile.scan(roots.reject { |root| root.to_s == Rails.root.to_s }) if compile

    # The taste tier: design-slop warnings join the mechanical
    # findings on request - same vocabulary, same JSON/text output. The
    # stock-theme nudge fires only for a FOREIGN DESIGN.md (a brand waiting
    # to be applied) - poetry's own export IS the current state.
    if ENV["POETRY_CHECK_DESIGN"] == "1"
      # DesignLint herb-parses templates - the .rb paths in the sweep are
      # the declaration tier's, not its; mailer templates are not pages
      # (no stylesheet, no tokens) and skip the taste tier too.
      findings += paths.grep(/\.erb\z/).reject { |path| Poetry::Core::Check.mail_template?(path, root: Rails.root) }
                       .flat_map { |path| Poetry::Core::DesignLint.lint(File.read(path), file: path) }
      design_md = Rails.root.join("DESIGN.md")
      foreign = design_md.exist? && Poetry::Core::DesignMd.parse(design_md.read)["theme"].nil?
      findings += Poetry::Core::DesignLint.lint_dom(
        doc: nil,
        context: { design_md_present: foreign,
                   overrides_present: Rails.root.join("app/assets/tailwind/poetry/design-overrides.css").exist? }
      )
    end

    # The shared-name tier: every poetry token name or theme key the app's
    # own stylesheets declare. Poetry's values are defaults, so the host's
    # win inside poetry's components too - a warning that says which, and
    # what the role paints, so a name that means something else here is a
    # decision and not a surprise. The installer prints the same report.
    findings += Poetry::Core::CSS::TokenCollisions.scan(root: Rails.root).collisions.map do |collision|
      Poetry::Core::Check::Finding.new(rule: "token-collision", severity: :warning,
                                       message: "#{collision.name} is yours, so it wins inside poetry's " \
                                                "components too - poetry uses it for #{collision.role}",
                                       file: collision.path, line: collision.line)
    end

    # The committed app registry (poetry:registry) against the live
    # classes: stale means the MCP server describes components the app no
    # longer has, or misses new ones. Missing is not a finding (opt-in).
    if Poetry::Core::Registry.invalid_at?(Rails.root)
      findings << Poetry::Core::Check::Finding.new(
        rule: "registry-invalid", severity: :warning, file: Poetry::Core::Registry::RELATIVE_PATH,
        message: "the committed app registry is not a registry file (empty, malformed, or the wrong shape) - " \
                 "run `bin/rails poetry:registry` to rewrite it; until then the boot-free surfaces ignore it"
      )
    elsif Poetry::Core::HostComponents.committed_state(root: Rails.root) == :stale
      findings << Poetry::Core::Check::Finding.new(
        rule: "registry-stale", severity: :warning, file: Poetry::Core::Registry::RELATIVE_PATH,
        message: "the committed app registry no longer matches app/components - run " \
                 "`bin/rails poetry:registry` and commit (poetry:verify fails on this)"
      )
    end

    # A Tailwind entry with neither preflight nor poetry's reset floor:
    # the components lose the normalizations they lean on (measured
    # against the golden corpus). One line, like the installer's.
    entry = Rails.root.join("app/assets/tailwind/application.css")
    if entry.exist? && Poetry::Ui::ResetFloor.entry_state(entry.read) == :none
      findings << Poetry::Core::Check::Finding.new(
        rule: "preflight-missing", severity: :warning, file: "app/assets/tailwind/application.css",
        message: "the Tailwind entry imports neither preflight nor poetry's reset floor - run " \
                 "`bin/rails g poetry:install --no-preflight` to vendor the floor (the components lean on " \
                 "preflight's normalizations)"
      )
    end

    # The app's controllers manifest (poetry:stimulus:manifest) against
    # the sources: stale means validation runs against controllers the
    # app no longer has. Missing is not a finding (opt-in).
    if Poetry::Core::Stimulus::HostManifest.state(root: Rails.root) == :stale
      findings << Poetry::Core::Check::Finding.new(
        rule: "manifest-stale", severity: :warning, file: Poetry::Core::Stimulus::HostManifest::RELATIVE_PATH,
        message: "the app's controllers manifest no longer matches app/javascript/controllers - run " \
                 "`bin/rails poetry:stimulus:manifest` and commit (poetry:verify fails on this)"
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
