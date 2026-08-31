# frozen_string_literal: true

namespace :docs do
  desc "Regenerate data/api/*.json from the sibling gems' YARD registries"
  task :api_reference do
    root = Rails.root
    gems = %w[poetry-core poetry-ui poetry-charts poetry-agent poetry-simple_form poetry-extract]
    out_dir = root.join("data/api")
    FileUtils.mkdir_p(out_dir)

    gems.each do |gem|
      gem_root = root.join("..", gem).expand_path
      next warn("skip #{gem}: not found") unless gem_root.exist?

      out = out_dir.join("#{gem}.json")
      # The child must run in the GEM's bundle, not the docs app's - shed
      # this process's bundler env entirely before re-entering bundler.
      ok = Bundler.with_unbundled_env do
        system(
          { "BUNDLE_GEMFILE" => gem_root.join("Gemfile").to_s },
          "bundle", "exec", "ruby", root.join("script/export_yard.rb").to_s,
          gem_root.to_s, out.to_s,
          chdir: gem_root.to_s
        )
      end
      abort "docs:api_reference failed for #{gem}" unless ok
    end

    # The JS sibling: @poetry/controllers from poetry-core's JSDoc + the
    # controllers manifest (pure file parsing - no bundle switch needed).
    core_root = root.join("..", "poetry-core").expand_path
    if core_root.exist?
      ok = system(
        RbConfig.ruby, root.join("script/export_jsdoc.rb").to_s,
        core_root.to_s, out_dir.join("poetry-controllers.json").to_s
      )
      abort "docs:api_reference failed for @poetry/controllers" unless ok
    else
      warn "skip @poetry/controllers: poetry-core not found"
    end
  end
end
