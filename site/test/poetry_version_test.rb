require "test_helper"

# The family the site runs on is one version; a bundle that resolves from
# RubyGems (CI, clones, deploys) runs the release pinned in .poetry-version;
# and the API reference data was generated from the version now loaded.
class PoetryVersionTest < ActiveSupport::TestCase
  PINNED = Rails.root.join(".poetry-version").read.strip
  LOADED = {
    "poetry-core" => Poetry::Core::VERSION, "poetry-ui" => Poetry::Ui::VERSION,
    "poetry-lucide" => Poetry::Lucide::VERSION, "poetry-charts" => Poetry::Charts::VERSION,
    "poetry-agent" => Poetry::Agent::VERSION
  }.freeze

  test "the loaded family is one version" do
    assert_equal 1, LOADED.values.uniq.size, LOADED.inspect
  end

  test "a RubyGems bundle runs the pinned release" do
    spec = Bundler.definition.specs.find { |candidate| candidate.name == "poetry-core" }
    skip "sibling checkouts in use (Gemfile.siblings); nothing is pinned" if spec.source.is_a?(Bundler::Source::Path)

    assert_equal PINNED, Poetry::Core::VERSION, ".poetry-version and the bundle disagree - bump one of them"
  end

  test "the API reference data was generated from the loaded version" do
    Rails.root.glob("data/api/*.json").each do |file|
      stamp = JSON.parse(file.read)["poetry_version"]

      assert_equal Poetry::Core::VERSION, stamp, "#{file.basename}: run bin/rails docs:api_reference"
    end
  end
end
