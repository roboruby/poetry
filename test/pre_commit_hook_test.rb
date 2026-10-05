# frozen_string_literal: true

require "test_helper"
require "json"
require "open3"
require "tmpdir"
require "fileutils"

# The pre-commit hook under .githooks regenerates a gem's committed
# manifests when a commit touches the gem's JavaScript. Exercised on a
# throwaway repository whose hooks path points at the real hook.
class PreCommitHookTest < Minitest::Test
  HOOKS = File.expand_path("../.githooks", __dir__)
  CONTROLLER = "gems/fake/app/javascript/a.js"
  MANIFEST = "gems/fake/config/controllers_manifest.json"

  def setup
    skip "npm is not on PATH" unless system("npm", "--version", out: File::NULL, err: File::NULL)
    @dir = Dir.mktmpdir("poetry-hook")
    git "init", "-q"
    { "user.email" => "hook@test", "user.name" => "hook", "commit.gpgsign" => "false", "core.hooksPath" => HOOKS }
      .each { |key, value| git "config", key, value }
    seed_the_gem
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir
  end

  def test_a_staged_controller_change_regenerates_and_stages_the_manifest
    write CONTROLLER, "two\n"
    git "add", CONTROLLER

    out = git "commit", "-q", "-m", "change"

    assert_includes out, "controllers_manifest.json regenerated and staged"
    assert_equal "two\n", git("show", "HEAD:#{MANIFEST}")
    assert_empty git("status", "--porcelain"), "the regenerated file rode the commit, nothing left behind"
  end

  def test_a_fresh_manifest_is_reported_and_left_alone
    write CONTROLLER, "two\n"
    write MANIFEST, "two\n"
    git "add", CONTROLLER, MANIFEST

    out = git "commit", "-q", "-m", "change with its manifest"

    assert_includes out, "gems/fake: manifests fresh"
    assert_equal "two\n", git("show", "HEAD:#{MANIFEST}")
  end

  def test_a_commit_without_javascript_never_runs_the_generator
    write "gems/fake/README.md", "notes\n"
    # An unstaged controller edit beside it: not this commit's business.
    write CONTROLLER, "three\n"
    git "add", "gems/fake/README.md"

    out = git "commit", "-q", "-m", "docs"

    refute_includes out, "pre-commit"
    assert_equal "one\n", git("show", "HEAD:#{MANIFEST}")
  end

  def test_unstaged_javascript_beside_the_staged_change_stops_the_commit
    write CONTROLLER, "two\n"
    git "add", CONTROLLER
    write CONTROLLER, "two and a half\n"

    out, status = run_git "commit", "-q", "-m", "partial"

    refute_predicate status, :success?
    assert_includes out, "JavaScript changes outside the index (#{CONTROLLER})"
    assert_equal "seed", git("log", "-1", "--format=%s").strip
  end

  def test_a_failing_generator_stops_the_commit_with_its_output
    write "gems/fake/package.json", JSON.generate(scripts: { manifest: "echo 'no controllers' && exit 3" })
    write CONTROLLER, "two\n"
    git "add", "-A"

    out, status = run_git "commit", "-q", "-m", "broken"

    refute_predicate status, :success?
    assert_match(%r{`npm run manifest` failed in gems/fake\n.*no controllers}m, out)
    assert_equal "seed", git("log", "-1", "--format=%s").strip
  end

  private

  # A gem whose manifest script copies the controller file, so the
  # manifest's content tells which sources it was generated from.
  def seed_the_gem
    script = "mkdir -p config && cat app/javascript/a.js > config/controllers_manifest.json"
    write "gems/fake/package.json", JSON.generate(scripts: { manifest: script })
    write CONTROLLER, "one\n"
    write MANIFEST, "one\n"
    git "add", "-A"
    git "commit", "-q", "-m", "seed"
  end

  def write(path, content)
    full = File.join(@dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def run_git(*)
    Open3.capture2e("git", *, chdir: @dir)
  end

  def git(*args)
    out, status = run_git(*args)
    flunk "git #{args.join(" ")} failed:\n#{out}" unless status.success?
    out
  end
end
