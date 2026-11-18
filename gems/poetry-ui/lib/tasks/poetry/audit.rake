# frozen_string_literal: true

# The consumer-app audit: the inventory against the catalog, the paint
# outside the tokens, the check's and the design tier's findings, the
# partials nothing renders, the routes, pages and edges. Writes
# .poetry/audit/{summary,inventory,health,flows}.json and report.html, and
# prints the summary (POETRY_AUDIT_JSON=1 prints the summary as JSON).
# Loaded automatically by the engine (lib/tasks).
namespace :poetry do
  desc "Audit the app: components and axes used, raw colors, font sizes, findings, dead partials, routes and " \
       "edges -> .poetry/audit/ (POETRY_AUDIT_JSON=1 prints the summary as JSON; POETRY_COMPILED_CSS overrides " \
       "the stylesheet the report inlines)"
  task audit: :environment do
    unless Poetry::Core::CSS::TemplateClasses.available?
      abort "poetry:audit: the herb gem is required to parse templates - " \
            "`bin/rails g poetry:install` adds it to your development group"
    end

    Rails.application.eager_load!
    compiled = ENV["POETRY_COMPILED_CSS"] || Rails.root.join("app/assets/builds/tailwind.css").to_s
    audit = Poetry::Ui::Audit.new(root: Rails.root, catalog: Poetry::Ui::CheckCatalog.build(root: Rails.root),
                                  routes: Poetry::Ui::Audit.routes_from(Rails.application.routes),
                                  compiled_css: compiled, app: Rails.application.class.module_parent_name)
    audit.run
    files = audit.write

    if ENV["POETRY_AUDIT_JSON"] == "1"
      puts JSON.pretty_generate(audit.data["summary"])
    else
      puts audit.summary_text
      puts "  wrote       #{files.map { |file| file.relative_path_from(Rails.root) }.join(", ")}"
      puts "  the report  open #{files.last.relative_path_from(Rails.root)}" \
           "#{" (no compiled stylesheet at #{compiled}: unstyled)" unless File.exist?(compiled)}"
    end
  end
end
