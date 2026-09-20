# frozen_string_literal: true

require "test_helper"

# A gem RubyGems already serves, with the attestation it serves for it: if a
# json or sigstore bump ever breaks verification, it fails here, in the
# releaser's tests, and never inside a release.
class VerifyFixtureTest < Minitest::Test
  FIXTURES = File.expand_path("fixtures", __dir__)

  def test_the_published_umbrella_bundle_verifies_against_the_release_workflow_identity
    gem = File.join(FIXTURES, "poetry-0.1.5.gem")
    identity = Releaser::Sign.identity(repository: "roboruby/poetry", ref: "refs/tags/v0.1.5")
    assert Releaser::Sign.verify(gem, identity: identity)
  end

  def test_the_fixture_is_the_bytes_rubygems_serves
    assert_equal "23e07c7a54352cab432ae3050e745ea11a122c65bdee0e78cfd4f7d04b9f1b00",
                 Digest::SHA256.file(File.join(FIXTURES, "poetry-0.1.5.gem")).hexdigest
  end
end
