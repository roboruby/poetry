# frozen_string_literal: true

# poetry check: lint consumer/agent-written ERB against the committed
# registry + controllers manifest. The mechanical, self-correctable gate an
# agent runs before its work is reviewed.
#
#   bundle exec rake poetry:check[app/views/**/*.html.erb]
#   POETRY_CHECK_JSON=1 bundle exec rake poetry:check[path]   # editor/CI output

def poetry_check_catalog
  Poetry::Core::Check::Catalog.from_registry(
    Poetry::Ui.root,
    helpers: Poetry::Ui::ComponentsHelper.public_instance_methods(false).grep(/\Apoetry_/),
    icon_names: poetry_check_icon_names
  )
end

# The active icon set's names, for the value-contract tier. A host
# without a registered set still checks icon-name SHAPE - membership is
# extra rigor, never a requirement.
def poetry_check_icon_names
  Poetry::Core::Icons.set.names
rescue Poetry::Core::Error
  nil
end

namespace :poetry do
  desc "Lint consumer ERB against the poetry registry (glob arg; POETRY_CHECK_JSON=1 for JSON)"
  task :check, [:glob] do |_task, args|
    poetry_ui_boot!

    glob = args[:glob] || "app/**/*.html.erb"
    paths = Dir.glob(glob)
    if paths.empty?
      # Tripwire floor: an empty glob means the path is wrong (or the boot
      # is broken), and a linter that scanned nothing must not pass green.
      abort "poetry check: no files matched #{glob.inspect} - check the glob/path"
    end

    findings = Poetry::Core::Check::Runner.new(poetry_check_catalog).run(paths)
    # The taste tier (N14 W3): design-slop warnings on request.
    if ENV["POETRY_CHECK_DESIGN"] == "1"
      findings += paths.flat_map { |path| Poetry::Core::DesignLint.lint(File.read(path), file: path) }
    end

    if ENV["POETRY_CHECK_JSON"] == "1"
      puts Poetry::Core::Check.to_json(findings)
    else
      puts Poetry::Core::Check.to_text(findings)
    end

    # Non-zero exit on any error-severity finding (CI-friendly).
    exit 1 if findings.any? { |finding| finding.severity == :error }
  end
end
