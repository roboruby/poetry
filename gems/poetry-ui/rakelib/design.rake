# frozen_string_literal: true

# DESIGN.md interop exports: every shipped theme serialized as the
# design-skill ecosystem's shared artifact (google-labs front matter +
# canonical sections), committed under docs/design/ and drift-gated like
# every other generated artifact. Hosts get their own export via
# `bin/rails poetry:design:export` (lib/tasks).

def poetry_design_export_pairs
  count = YAML.safe_load_file(Poetry::Ui.root.join(Poetry::Core::Registry::RELATIVE_PATH))
              .fetch("components").size
  Poetry::Ui::Themes.design_md_exports(components_count: count).transform_keys do |name|
    "docs/design/#{name}.design.md"
  end
end

namespace :design do
  desc "Export every shipped theme as a DESIGN.md interop file (docs/design/<theme>.design.md)"
  task :export_all do
    poetry_ui_boot!
    dir = Poetry::Ui.root.join("docs/design")
    dir.mkpath
    poetry_design_export_pairs.each do |relative, content|
      Poetry::Ui.root.join(relative).write(content)
      puts "regenerated #{relative}"
    end
  end

  desc "Fail if any committed DESIGN.md export is stale (the CI drift gate)"
  task :verify do
    poetry_ui_boot!
    stale = poetry_design_export_pairs.reject do |relative, content|
      path = Poetry::Ui.root.join(relative)
      path.exist? && path.read == content
    end.keys
    if stale.empty?
      puts "DESIGN.md exports in sync (#{poetry_design_export_pairs.size} themes)"
    else
      abort "stale DESIGN.md exports: #{stale.join(", ")} - run `bin/rake design:export_all` and commit"
    end
  end

  desc "Design-slop lint: the AST tier over the gem's templates + the DOM tier over rendered previews"
  task :lint do
    poetry_ui_boot!
    paths = Dir[Poetry::Ui.root.join("app/components/**/*.html.erb").to_s]
    findings = paths.flat_map do |path|
      relative = Pathname.new(path).relative_path_from(Poetry::Ui.root).to_s
      Poetry::Core::DesignLint.lint(File.read(path), file: relative)
    end
    puts Poetry::Core::Check.to_text(findings)
    abort "design:lint: AST-tier findings above" if findings.any?

    puts "design:lint: AST tier clean (#{paths.size} templates); running the DOM tier (dommy)..."
    sh "bundle exec ruby -Itest test/dommy_tier/design_dom_test.rb"
  end

  # The motion self-audit: run the motion floor over the theme
  # layer's own @apply utilities, where poetry's motion actually lives.
  # REPORT-ONLY, not a gate: the findings are upstream-ported timings, so
  # re-timing them is a design decision (it diverges from the faithful
  # port and re-feels all nine themes), surfaced here rather than silently
  # changed. The floor still GATES host + component ERB through design:lint.
  desc "Motion self-audit: the motion floor over the theme layer (report-only)"
  task :motion do
    poetry_ui_boot!
    themes = Dir[Poetry::Ui.root.join("themes/*.css").to_s]
    enforced = []
    advisories = []
    themes.each do |path|
      relative = Pathname.new(path).relative_path_from(Poetry::Ui.root).to_s
      File.readlines(path).each_with_index do |line, index|
        classes = line[/@apply\s+([^;]+);/, 1]&.split
        next unless classes

        Poetry::Core::DesignLint.motion_class_findings(classes, index + 1).each do |f|
          enforced << f.tap { f.file = relative }
        end
        Poetry::Core::DesignLint.transition_all_advisory(classes, index + 1).each do |f|
          advisories << f.tap { f.file = relative }
        end
      end
    end
    if enforced.empty?
      puts "design:motion: theme layer clean against the ENFORCED motion floor (#{themes.size} themes)"
    else
      puts Poetry::Core::Check.to_text(enforced)
      puts "design:motion: #{enforced.size} ENFORCED motion-floor finding(s) - these should not ship"
    end
    unless advisories.empty?
      puts Poetry::Core::Check.to_text(advisories)
      puts "design:motion: #{advisories.size} transition-all advisory site(s) - REPORT-ONLY " \
           "(upstream-ported; re-timing to specific transitions is a design decision, not a gate)"
    end
  end
end
