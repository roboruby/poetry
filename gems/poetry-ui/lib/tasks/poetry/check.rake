# frozen_string_literal: true

# Host-side poetry check (, exposed to apps in N14 W1 - AGENTS.md had
# promised `bin/rails poetry:check` since N13; this makes it true): lint
# the app's ERB against the committed registry + controllers manifest.
# Loaded automatically by the engine (lib/tasks).
namespace :poetry do
  desc "Lint app ERB against the poetry registry " \
       "(glob arg, default app/{views,components}/**/*.html.erb; POETRY_CHECK_JSON=1 for JSON)"
  task :check, [:glob] => :environment do |_task, args|
    # The linter parses ERB with herb, which stays out of poetry's runtime
    # dependencies on purpose (hosts never need it to RENDER) - same
    # optional-parser posture as poetry:verify's template gate.
    unless Poetry::Core::CSS::TemplateClasses.available?
      abort "poetry:check: the herb gem is required to parse templates - " \
            "add `gem \"herb\"` to your Gemfile (development group is enough)"
    end

    glob = args[:glob] || "app/{views,components}/**/*.html.erb"
    paths = Dir.glob(Rails.root.join(glob).to_s)
    if paths.empty?
      warn "poetry check: no files matched #{glob.inspect}"
      exit 0
    end

    helpers = Poetry::Ui.helper_names
    if defined?(Poetry::Charts::ComponentsHelper)
      helpers += Poetry::Charts::ComponentsHelper.public_instance_methods(false)
                                                 .grep(/\Apoetry_/).map(&:to_s)
    end
    catalog = Poetry::Core::Check::Catalog.from_registry(Poetry::Ui.root, helpers: helpers)
    findings = Poetry::Core::Check::Runner.new(catalog).run(paths)

    if ENV["POETRY_CHECK_JSON"] == "1"
      puts Poetry::Core::Check.to_json(findings)
    else
      puts Poetry::Core::Check.to_text(findings)
    end

    exit 1 if findings.any? { |finding| finding.severity == :error }
  end
end
