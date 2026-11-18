require "test_helper"

# The Claude Code plugin at the repository root is generated from the same
# skills an app installs. These hold the committed files to their source
# and the manifests to the rules Claude Code reads them by.
class PluginBundleTest < ActiveSupport::TestCase
  Bundle = Poetry::Docs::PluginBundle

  test "the committed plugin matches the skills it is generated from" do
    assert_empty Bundle.stale, "the plugin is stale - run bundle exec rake poetry_docs:plugin and commit"
  end

  test "the plugin carries every skill the catalog serves, file for file" do
    files = Bundle.files

    Poetry::Docs::SkillCatalog.sets.each do |name, set|
      set.each { |relative, content| assert_equal content, files.fetch("plugins/poetry/skills/#{name}/#{relative}") }
      assert_predicate Poetry::Docs::SkillCatalog.description(set), :present?, "#{name} needs a description to be offered"
    end
    assert_equal Poetry::Docs::SkillCatalog.sets.sum { |_name, set| set.size } + 2, files.size
  end

  test "the marketplace names one plugin, in a folder of this repository" do
    manifest = JSON.parse(Bundle.files.fetch(".claude-plugin/marketplace.json"))
    entry = manifest.fetch("plugins").sole

    assert_match(/\A[a-z0-9][a-z0-9._-]*\z/, manifest.fetch("name"))
    assert_predicate manifest.dig("owner", "name"), :present?
    assert_predicate manifest.fetch("description"), :present?
    assert_equal "./plugins/poetry", entry.fetch("source")
    assert_predicate Bundle.root.join(entry.fetch("source"), ".claude-plugin/plugin.json"), :file?
    assert_equal "poetry", manifest.fetch("name")
  end

  test "the plugin manifest carries the gem's version and no reserved name" do
    plugin = JSON.parse(Bundle.files.fetch("plugins/poetry/.claude-plugin/plugin.json"))

    assert_match(/\A[a-z0-9]+(-[a-z0-9]+)*\z/, plugin.fetch("name"))
    refute_match(/\A(claude|anthropic|anthropics|cc-plugin)(-|\z)/, plugin.fetch("name"))
    assert_equal Poetry::Ui::VERSION, plugin.fetch("version")
    assert_equal "MIT", plugin.fetch("license")
    assert_equal %w[author description homepage keywords license name repository version], plugin.keys.sort
  end

  test "no manifest carries an email address" do
    manifests = Bundle.files.select { |path, _content| path.end_with?(".json") }

    assert_equal 2, manifests.size
    manifests.each_value { |content| refute_match(/@[a-z0-9-]+\.[a-z]/i, content) }
  end

  test "writing replaces the folder: what the plugin no longer has is removed, and the result is fresh" do
    Dir.mktmpdir do |dir|
      stray = Pathname(dir).join("plugins/poetry/skills/poetry/references/renamed-away.md")
      stray.dirname.mkpath
      stray.write("left over from an older skill")

      assert_includes Bundle.stale(dir), "plugins/poetry/skills/poetry/references/renamed-away.md"
      assert_equal Bundle.files.size, Bundle.write(dir)
      refute_predicate stray, :exist?
      assert_empty Bundle.stale(dir)

      Pathname(dir).join("plugins/poetry/skills/poetry/SKILL.md").write("edited by hand")

      assert_equal [ "plugins/poetry/skills/poetry/SKILL.md" ], Bundle.stale(dir)
    end
  end
end
