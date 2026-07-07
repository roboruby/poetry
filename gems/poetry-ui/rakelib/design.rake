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
end
