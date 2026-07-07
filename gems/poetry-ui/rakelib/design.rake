# frozen_string_literal: true

# DESIGN.md interop exports (N14 W1): every shipped theme serialized as the
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
end
