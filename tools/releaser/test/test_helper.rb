# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "releaser"

# A throwaway family tree with only the files the releaser touches: VERSION,
# every version.rb, the three package.json and a changelog per gem.
module TreeHelper
  def build_tree(version: "0.1.5", changelog: nil)
    dir = Dir.mktmpdir("releaser")
    File.write(File.join(dir, "VERSION"), "#{version}\n")
    Releaser::GEMS.each do |name|
      gem_dir = Releaser.gem_dir(name, dir)
      slug = name == "poetry" ? "poetry" : "poetry/#{name.delete_prefix('poetry-')}"
      path = File.join(gem_dir, "lib", slug, "version.rb")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "module Poetry\n  VERSION = \"#{version}\"\nend\n")
      File.write(File.join(gem_dir, "CHANGELOG.md"), changelog || default_changelog(name, version))
    end
    Releaser::PACKAGES.each do |pkg|
      FileUtils.mkdir_p(File.join(dir, pkg))
      File.write(File.join(dir, pkg, "package.json"),
                 "{\n  \"name\": \"#{File.basename(pkg)}\",\n  \"version\": \"#{version}\",\n  \"private\": true\n}\n")
      lock = { "name" => File.basename(pkg), "version" => version, "lockfileVersion" => 3,
               "packages" => { "" => { "name" => File.basename(pkg), "version" => version },
                               "node_modules/x" => { "version" => "9.9.9" } } }
      File.write(File.join(dir, pkg, "package-lock.json"), "#{JSON.pretty_generate(lock)}\n")
    end
    dir
  end

  def default_changelog(name, version)
    "# Changelog\n\n## [#{version}]\n\n### Changed\n\n- Something in #{name}.\n\n## [0.1.4] - 2026-09-01\n\n- Older.\n"
  end
end
