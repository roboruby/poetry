# frozen_string_literal: true

require "test_helper"

# Against the real tree: which gems minify, what the minifier writes, and the
# check that a built gem carries a minified twin of every source file.
class MinifyTest < Minitest::Test
  ROOT = Releaser::ROOT

  def test_the_gems_with_an_importmap_tree_minify_and_the_docs_engine_does_not
    gems = Releaser::Minify.gems(ROOT)

    assert_includes gems, "poetry-core"
    assert_includes gems, "poetry-charts"
    assert_includes gems, "poetry-agent"
    refute_includes gems, "poetry-docs"
    refute_includes gems, "poetry-ui"
  end

  def test_every_source_file_gets_a_minified_twin_and_a_source_map
    skip_without_esbuild
    dist = Releaser::Minify.run(ROOT, "poetry-agent")
    source = File.join(Releaser.gem_dir("poetry-agent", ROOT), "app/javascript")
    files = Dir.glob("**/*.js", base: source)

    refute_empty files
    files.each do |path|
      minified = File.read(File.join(dist, "javascript", path))
      map = JSON.parse(File.read(File.join(dist, "javascript", "#{path}.map")))

      assert_operator minified.bytesize, :<, File.size(File.join(source, path)), path
      assert minified.end_with?("//# sourceMappingURL=#{File.basename(path)}.map\n"), path
      assert_equal [File.read(File.join(source, path))], map["sourcesContent"], path
    end
  ensure
    FileUtils.rm_rf(Releaser::Minify.dist(ROOT, "poetry-agent"))
  end

  def test_a_prebuilt_bundle_is_copied_byte_for_byte
    skip_without_esbuild
    dist = Releaser::Minify.run(ROOT, "poetry-charts")
    path = "poetry/charts/d3.js"

    assert_equal File.binread(File.join(Releaser.gem_dir("poetry-charts", ROOT), "app/javascript", path)),
                 File.binread(File.join(dist, "javascript", path))
    refute_path_exists File.join(dist, "javascript", "#{path}.map")
  ensure
    FileUtils.rm_rf(Releaser::Minify.dist(ROOT, "poetry-charts"))
  end

  def test_missing_names_the_source_files_a_gem_would_ship_without_a_twin
    source = File.join(Releaser.gem_dir("poetry-agent", ROOT), "app/javascript")
    twins = Dir.glob("**/*.js", base: source).map { |path| "dist/javascript/#{path}" }

    assert_empty Releaser::Minify.missing(ROOT, "poetry-agent", twins + ["lib/poetry/agent.rb"])
    assert_equal [twins.first], Releaser::Minify.missing(ROOT, "poetry-agent", twins.drop(1))
  end

  private

  def skip_without_esbuild
    return if File.directory?(File.join(ROOT, Releaser::Minify::MINIFIER, "node_modules", "esbuild"))

    skip "tools/minifier needs `npm ci`"
  end
end
