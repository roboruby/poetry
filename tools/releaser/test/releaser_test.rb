# frozen_string_literal: true

require "test_helper"

class VersionsTest < Minitest::Test
  include TreeHelper

  def test_stamp_rewrites_every_version_file_and_package_once
    root = build_tree(version: "0.1.5")
    changed = Releaser::Versions.stamp(root, "0.1.6")
    assert_equal Releaser::GEMS.size + (Releaser::PACKAGES.size * 2), changed.size
    assert_empty Releaser::Versions.mismatches(root, "0.1.6")
    assert_empty Releaser::Versions.stamp(root, "0.1.6"), "a second stamp changes nothing"
  end

  def test_mismatches_name_every_file_that_disagrees
    root = build_tree(version: "0.1.5")
    out = Releaser::Versions.mismatches(root, "0.1.6")
    assert_equal Releaser::GEMS.size + (Releaser::PACKAGES.size * 3), out.size, "version.rb, package.json and two lock fields"
    assert out.all? { |line| line.end_with?(": \"0.1.5\"") }, out.inspect
  end

  def test_package_json_keeps_its_formatting
    root = build_tree(version: "0.1.5")
    Releaser::Versions.stamp(root, "0.1.6")
    text = File.read(File.join(root, Releaser::PACKAGES.first, "package.json"))
    assert_includes text, "  \"version\": \"0.1.6\",\n"
    assert_includes text, "  \"private\": true\n"
  end
end

class ChangelogTest < Minitest::Test
  include TreeHelper

  def test_dates_the_undated_heading
    root = build_tree
    path = File.join(root, "gems/poetry-core/CHANGELOG.md")
    assert_equal :dated, Releaser::Changelog.date(path, "0.1.5", "2026-09-19")
    assert_includes File.read(path), "## [0.1.5] - 2026-09-19\n"
    assert_equal :unchanged, Releaser::Changelog.date(path, "0.1.5", "2026-09-20")
    assert_includes File.read(path), "## [0.1.5] - 2026-09-19\n", "an already dated heading keeps its date"
  end

  def test_inserts_a_no_changes_section_before_the_first_heading
    root = build_tree(changelog: "# Changelog\n\n## [0.1.4] - 2026-09-01\n\n- Older.\n")
    path = File.join(root, "gems/poetry-ui/CHANGELOG.md")
    assert_equal :inserted, Releaser::Changelog.date(path, "0.1.5", "2026-09-19")
    text = File.read(path)
    assert_operator text.index("## [0.1.5] - 2026-09-19"), :<, text.index("## [0.1.4]")
    assert_equal Releaser::NO_CHANGES, Releaser::Changelog.section(path, "0.1.5").lines.last.strip
  end

  def test_section_is_the_body_between_headings
    root = build_tree
    path = File.join(root, "gems/poetry-charts/CHANGELOG.md")
    assert_equal "### Changed\n\n- Something in poetry-charts.", Releaser::Changelog.section(path, "0.1.5")
    assert_equal "- Older.", Releaser::Changelog.section(path, "0.1.4")
    assert_nil Releaser::Changelog.section(path, "0.0.1")
  end
end

class NotesTest < Minitest::Test
  include TreeHelper

  def test_assembles_every_gem_in_publish_order
    root = build_tree
    notes = Releaser::Notes.assemble(root, "0.1.5")
    assert notes.start_with?("# Poetry 0.1.5\n\n## poetry-core\n\n### Changed\n\n- Something in poetry-core.")
    positions = Releaser::GEMS.map { |name| notes.index("## #{name}\n") }
    assert_equal positions.sort, positions
    assert notes.end_with?("- Something in poetry.\n")
  end

  def test_a_gem_without_a_section_reads_no_changes
    root = build_tree
    File.write(File.join(root, "gems/poetry-extract/CHANGELOG.md"), "# Changelog\n\n## [0.1.4] - 2026-09-01\n\n- Older.\n")
    notes = Releaser::Notes.assemble(root, "0.1.5")
    assert_includes notes, "## poetry-extract\n\n#{Releaser::NO_CHANGES}\n"
  end
end

class PushTest < Minitest::Test
  def test_decision_table
    assert_equal :push, Releaser::Push.decision(nil, "abc")
    assert_equal :skip, Releaser::Push.decision("abc", "abc")
    assert_equal :abort, Releaser::Push.decision("abc", "def")
  end
end

class SignTest < Minitest::Test
  def test_identity_is_the_workflow_ref_uri
    assert_equal "https://github.com/roboruby/poetry/.github/workflows/release.yml@refs/tags/v0.1.6",
                 Releaser::Sign.identity(repository: "roboruby/poetry", ref: "refs/tags/v0.1.6")
  end

  def test_bundle_sits_beside_the_gem
    assert_equal "pkg/poetry-core-0.1.6.gem.sigstore.json", Releaser::Sign.bundle_for("pkg/poetry-core-0.1.6.gem")
  end
end

class TagTest < Minitest::Test
  include TreeHelper

  def test_rejects_a_ref_that_is_not_the_version_tag
    root = build_tree(version: "0.1.5")
    error = assert_raises(Releaser::Error) { Releaser::Tag.verify(root, "v0.1.6", "0.1.5") }
    assert_includes error.message, "expected v0.1.5"
  end

  def test_rejects_version_files_that_disagree
    root = build_tree(version: "0.1.4")
    error = assert_raises(Releaser::Error) { Releaser::Tag.verify(root, "v0.1.5", "0.1.5") }
    assert_includes error.message, "disagree"
  end

  def test_accepts_a_tag_on_main_and_rejects_one_off_it
    root = build_tree(version: "0.1.5")
    git = ->(*args) { system("git", "-C", root, *args, out: File::NULL, err: File::NULL) || raise("git #{args.join(' ')}") }
    git.call("init", "-q", "-b", "main")
    git.call("-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-q", "--allow-empty", "-m", "one")
    git.call("tag", "v0.1.5")
    assert Releaser::Tag.verify(root, "v0.1.5", "0.1.5", main: "main")
    git.call("checkout", "-q", "-b", "side")
    git.call("-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-q", "--allow-empty", "-m", "two")
    git.call("tag", "-f", "v0.1.5")
    error = assert_raises(Releaser::Error) { Releaser::Tag.verify(root, "v0.1.5", "0.1.5", main: "main") }
    assert_includes error.message, "not an ancestor"
  end
end

class PackageLockTest < Minitest::Test
  include TreeHelper

  def test_stamps_both_lock_versions_and_leaves_dependencies_alone
    root = build_tree(version: "0.1.5")
    lock = File.join(root, Releaser::PACKAGES.first, "package-lock.json")
    Releaser::Versions.stamp(root, "0.1.6")
    parsed = JSON.parse(File.read(lock))
    assert_equal "0.1.6", parsed["version"]
    assert_equal "0.1.6", parsed.dig("packages", "", "version")
    assert_equal "9.9.9", parsed.dig("packages", "node_modules/x", "version")
    assert_empty Releaser::Versions.mismatches(root, "0.1.6")
    lock_lines = Releaser::Versions.mismatches(root, "0.1.5").count { |line| line.include?("package-lock.json") }
    assert_equal Releaser::PACKAGES.size * 2, lock_lines, "two versions per lock disagree with the old number"
  end
end
