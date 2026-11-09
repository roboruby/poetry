# frozen_string_literal: true

require "test_helper"
require "a2ui_conformance"

# A2UI's renderer conformance suites (test/fixtures/a2ui/upstream, vendored
# at the commit in its COMMIT file), one test per case. A case Poetry does
# not pass is listed in test/fixtures/a2ui/divergences.yml with what closes
# it; a listed case that starts passing fails the suite, so the list only
# shrinks.
class ConformanceTest < Minitest::Test
  DIVERGENCES = YAML.safe_load_file(File.expand_path("../../../fixtures/a2ui/divergences.yml", __dir__)) || {}

  # The reason a case fails, or nil when Poetry passes it.
  def self.outcome(test_case)
    A2UIConformance.run(test_case)
  rescue A2UIConformance::Failure => e
    e.message
  rescue StandardError => e
    "#{e.class} raised: #{e.message[0, 200]}"
  end

  # Every case in the vendored suites, keyed suite::name.
  def self.all_cases
    A2UIConformance::SUITES.flat_map do |suite|
      A2UIConformance.cases(suite).map { |test_case| ["#{suite}::#{test_case["name"]}", test_case] }
    end
  end

  def test_every_listed_divergence_is_a_vendored_case
    assert_empty DIVERGENCES.keys - self.class.all_cases.map(&:first), "stale entries in divergences.yml"
  end

  all_cases.each do |key, test_case|
    define_method("test_#{key.sub("::test_", "__").sub("::", "__")}") do
      failure = self.class.outcome(test_case)
      if DIVERGENCES.key?(key)
        refute_nil failure, "#{key} passes now (#{DIVERGENCES[key]}): drop it from divergences.yml"
      else
        assert_nil failure, "#{key}: #{test_case["description"]}"
      end
    end
  end
end
