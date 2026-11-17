# frozen_string_literal: true

# The engine's generated surfaces, regenerated in the monorepo after the
# gems change (the release train runs poetry_docs:refresh at bump time):
# the agent skills under .claude/skills, the API reference under data/api,
# the search index under data/, the gems' CSS vendored under tailwind/, and
# the built stylesheet under app/assets/builds. A host that bundles the
# engine gets these tasks too; they refuse to run outside the monorepo
# checkout.
namespace :poetry_docs do
  monorepo = -> { Poetry::Docs.root.join("Rakefile").exist? && Poetry::Docs.root.join("..", "poetry-core").directory? }
  monorepo_only = lambda do |task|
    abort "#{task}: runs in the roboruby/poetry checkout only" unless monorepo.call
  end

  # The version constant of a sibling checkout, read from its version.rb -
  # stamped into every export so a stale reference file tells against the
  # version the engine runs.
  poetry_version_of = lambda do |gem_root|
    file = Dir.glob(gem_root.join("lib/**/version.rb").to_s).min_by(&:length)
    (file && File.read(file)[/VERSION = "([^"]+)"/, 1]) || abort("no VERSION under #{gem_root}")
  end
  stamp = lambda do |path, version|
    data = JSON.parse(File.read(path))
    File.write(path, JSON.pretty_generate({ "poetry_version" => version }.merge(data)) + "\n")
  end

  desc "Regenerate data/api/*.json from the sibling gems' YARD registries"
  task :api_reference do
    monorepo_only.call("poetry_docs:api_reference")
    root = Poetry::Docs.root
    gems = %w[poetry-core poetry-ui poetry-charts poetry-motion poetry-island poetry-agent poetry-simple_form
              poetry-extract]
    out_dir = root.join("data/api")
    FileUtils.mkdir_p(out_dir)

    gems.each do |gem|
      gem_root = root.join("..", gem).expand_path
      next warn("skip #{gem}: not found") unless gem_root.exist?

      out = out_dir.join("#{gem}.json")
      # The child must run in the GEM's bundle, not the engine's - shed
      # this process's bundler env entirely before re-entering bundler.
      ok = Bundler.with_unbundled_env do
        system(
          { "BUNDLE_GEMFILE" => gem_root.join("Gemfile").to_s },
          "bundle", "exec", "ruby", root.join("script/export_yard.rb").to_s,
          gem_root.to_s, out.to_s,
          chdir: gem_root.to_s
        )
      end
      abort "poetry_docs:api_reference failed for #{gem}" unless ok
      stamp.call(out, poetry_version_of.call(gem_root))
    end

    # The JS siblings: JSDoc + controllers-manifest exports (pure file
    # parsing - no bundle switch needed).
    { "poetry-core" => "poetry-controllers",
      "poetry-charts" => "poetry-charts-controllers",
      "poetry-motion" => "poetry-motion-controllers",
      "poetry-island" => "poetry-island-controllers",
      "poetry-agent" => "poetry-agent-controllers" }.each do |js_gem, slug|
      js_root = root.join("..", js_gem).expand_path
      next warn("skip #{slug}: #{js_gem} not found") unless js_root.exist?

      ok = system(
        RbConfig.ruby, root.join("script/export_jsdoc.rb").to_s,
        js_root.to_s, out_dir.join("#{slug}.json").to_s
      )
      abort "poetry_docs:api_reference failed for #{slug}" unless ok
      stamp.call(out_dir.join("#{slug}.json"), poetry_version_of.call(js_root))
    end
  end

  desc "Regenerate data/search-index.json from the rendered pages"
  task search_index: :environment do
    monorepo_only.call("poetry_docs:search_index")
    count = Poetry::Docs::SearchIndex.write!
    puts "wrote data/search-index.json (#{count} entries)"
  end

  desc "Install the poetry agent skills into the engine's .claude/skills (the docs' own authoring copy)"
  task skill: :environment do
    monorepo_only.call("poetry_docs:skill")
    require "rails/generators"
    Rails::Generators.invoke("poetry:skill", [ "--force" ], destination_root: Poetry::Docs.root.to_s)
  end

  desc "Rebuild data/eval-ledger.json from the judged runs stored under poetry-ui's eval/results"
  task eval_ledger: :environment do
    monorepo_only.call("poetry_docs:eval_ledger")
    count = Poetry::Docs::EvalLedger.write!
    puts "wrote data/eval-ledger.json (#{count} runs)"
  end

  desc "Write the Claude Code plugin the repository publishes: .claude-plugin/marketplace.json and plugins/poetry"
  task plugin: :environment do
    monorepo_only.call("poetry_docs:plugin")
    count = Poetry::Docs::PluginBundle.write
    puts "wrote the plugin (#{count} files under .claude-plugin and #{Poetry::Docs::PluginBundle::SOURCE})"
  end

  namespace :plugin do
    desc "Fail when the committed plugin differs from the skills and metadata it is generated from"
    task verify: :environment do
      monorepo_only.call("poetry_docs:plugin:verify")
      stale = Poetry::Docs::PluginBundle.stale
      if stale.any?
        abort "poetry_docs:plugin:verify: #{stale.size} file#{"s" if stale.size > 1} differ (#{stale.first(3).join(", ")}) " \
              "- run bundle exec rake poetry_docs:plugin and commit"
      end
      puts "poetry_docs:plugin: the committed plugin matches the skills"
    end
  end

  # The safelist an install would write in this host: every loaded gem's
  # style dictionaries plus poetry-ui's committed template classes
  # (poetry:install's own recipe, so the file reads as an installer's).
  vendored_safelist = lambda do
    Rails.application.eager_load!
    styles = Poetry::Core::Style.descendants.select(&:name)
    Poetry::Core::CSS::Safelist.new(style_classes: styles, template_classes: Poetry::Ui.template_classes).text
  end
  safelist_path = -> { Poetry::Docs.root.join("tailwind/poetry/safelist.txt") }
  style_registry = lambda do |*flags|
    system(RbConfig.ruby, Poetry::Docs.root.join("script/build_style_registry.rb").to_s, *flags)
  end

  desc "Sync the gems' CSS the docs vendor: the install slots under tailwind/poetry (safelist included) " \
       "and the nine wrapped themes under tailwind/styles"
  task vendored: :environment do
    monorepo_only.call("poetry_docs:vendored")
    abort "poetry_docs:vendored: script/build_style_registry.rb failed" unless style_registry.call
    safelist_path.call.write(vendored_safelist.call)
    puts "wrote tailwind/poetry/safelist.txt (#{safelist_path.call.read.lines.size} lines)"
  end

  namespace :vendored do
    # A theme rule or a dictionary class changed in a gem reaches the docs
    # only through these copies. Before this check a stale copy passed every
    # gate: the stylesheet verify rebuilds from the copies, so it agreed
    # with them, and the docs rendered the old rule.
    desc "Fail when a vendored copy of the gems' CSS (themes, install slots, safelist) differs from the gems"
    task verify: :environment do
      monorepo_only.call("poetry_docs:vendored:verify")
      stale = !style_registry.call("--check")
      path = safelist_path.call
      unless path.exist? && path.read == vendored_safelist.call
        stale = true
        warn "poetry_docs:vendored:verify: tailwind/poetry/safelist.txt no longer matches the gems' dictionaries " \
             "and template classes"
      end
      if stale
        abort "poetry_docs:vendored:verify: run bundle exec rake poetry_docs:vendored poetry_docs:css and commit"
      end
      puts "poetry_docs:vendored: the safelist matches the gems"
    end
  end

  desc "Build app/assets/builds/poetry_docs.css from tailwind/application.css (the nine-theme registry inside)"
  task :css do
    monorepo_only.call("poetry_docs:css")
    require "tailwindcss/ruby"
    root = Poetry::Docs.root
    FileUtils.mkdir_p(root.join("app/assets/builds"))
    ok = system(Tailwindcss::Ruby.executable, "-i", root.join("tailwind/application.css").to_s,
                "-o", root.join("app/assets/builds/poetry_docs.css").to_s, "--minify", chdir: root.to_s)
    abort "poetry_docs:css: the Tailwind build failed" unless ok
    puts "wrote app/assets/builds/poetry_docs.css (#{root.join("app/assets/builds/poetry_docs.css").size} bytes)"
  end

  namespace :css do
    desc "Build the docs stylesheet with the host app's own view folders added (config.stylesheet_sources), for host pages in the docs layout"
    task host: :environment do
      path = Poetry::Docs::HostStylesheet.build(root: Rails.root)
      puts "wrote #{path.relative_path_from(Rails.root)} (#{path.size} bytes)"
    end

    desc "Fail when the committed stylesheet differs from a fresh build"
    task :verify do
      root = Poetry::Docs.root
      committed = root.join("app/assets/builds/poetry_docs.css")
      abort "poetry_docs:css:verify: no committed stylesheet - run rake poetry_docs:css" unless committed.exist?
      before = committed.read
      Rake::Task["poetry_docs:css"].invoke
      # Tailwind has been seen to leave rules out of a build made on a busy
      # machine, so one build that differs is not yet a stale stylesheet.
      unless committed.read == before
        Rake::Task["poetry_docs:css"].reenable
        Rake::Task["poetry_docs:css"].invoke
      end
      if committed.read == before
        puts "poetry_docs:css: the committed stylesheet is fresh"
      else
        committed.write(before)
        abort "poetry_docs:css:verify: app/assets/builds/poetry_docs.css is stale - run rake poetry_docs:css and commit"
      end
    end
  end

  desc "Everything the engine regenerates after the gems change: the skills, the plugin, the eval ledger, " \
       "the API reference, the search index, the vendored CSS, the stylesheet"
  task :refresh do
    monorepo_only.call("poetry_docs:refresh")
    # The vendored copies before the stylesheet, which is built from them.
    %w[poetry_docs:skill poetry_docs:plugin poetry_docs:eval_ledger poetry_docs:api_reference
       poetry_docs:search_index poetry_docs:vendored poetry_docs:css].each do |name|
      Rake::Task[name].invoke
    end
  end
end

# A host that names stylesheet sources gets its docs stylesheet built with
# the rest of its assets, and before its tests, whose pages link it.
namespace :poetry_docs do
  task css_for_host: :environment do
    Rake::Task["poetry_docs:css:host"].invoke if Poetry::Docs.config.stylesheet_sources.any?
  end
end
%w[assets:precompile test:prepare].each do |name|
  Rake::Task[name].enhance([ "poetry_docs:css_for_host" ]) if Rake::Task.task_defined?(name)
end
