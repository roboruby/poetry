# frozen_string_literal: true

require "test_helper"

# Against the real tree: what the umbrella would ship, and the commit time the
# reproducible build pins.
class BuildTest < Minitest::Test
  def test_the_umbrella_ships_only_lib_and_the_three_documents
    files = Releaser::Build.umbrella_files(Releaser::ROOT)
    assert_includes files, "lib/poetry.rb"
    assert_includes files, "lib/poetry/version.rb"
    assert files.all? { |f| f.start_with?("lib/") || Releaser::UMBRELLA_DOCS.include?(f) }, files.inspect
    assert Releaser::Build.check_umbrella!(Releaser::ROOT)
  end

  def test_epoch_is_the_commit_time_of_the_ref
    assert_kind_of Integer, Releaser::Build.epoch(Releaser::ROOT, "HEAD")
    assert_raises(Releaser::Error) { Releaser::Build.epoch(Releaser::ROOT, "no-such-ref") }
  end

  def test_checksums_are_sha256_by_basename
    Dir.mktmpdir do |dir|
      path = File.join(dir, "x.gem")
      File.write(path, "poetry")
      assert_equal({ "x.gem" => Digest::SHA256.hexdigest("poetry") }, Releaser::Build.checksums([path]))
    end
  end
end
