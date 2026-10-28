# frozen_string_literal: true

require "test_helper"
require "agui_helper"

module Poetry
  module Agent
    module AGUI
      # The reference client's own unit-test vectors for the compatibility
      # boundary, chunk expansion and verification
      # (test/fixtures/agui/1.0/vectors), each events in and an outcome out,
      # run through a fresh strict pipeline.
      class VectorsTest < Minitest::Test
        Dir[File.join(AguiHelper::ROOT, "vectors", "*.json")].each do |path|
          file = File.basename(path, ".json")
          JSON.parse(File.read(path)).fetch("vectors").each_with_index do |vector, index|
            define_method("test_#{file.tr("-", "_")}_#{index}") do
              outcome = AguiHelper.run_pipeline(vector.fetch("input"))
              expect = vector.fetch("expect")
              label = "#{file} > #{vector["name"]} (line #{vector["line"]})"

              if expect.key?("error")
                refute_nil outcome[:error], "#{label}: expected a rejection containing #{expect["error"].inspect}"
                assert_includes outcome[:error].message, expect["error"], label
              else
                assert_nil outcome[:error], "#{label}: unexpected rejection #{outcome[:error]&.message.inspect}"
                if expect.key?("eventTypes")
                  assert_equal expect["eventTypes"], outcome[:events].map { |event| event["type"] }, label
                else
                  keys = AguiHelper.ignored_keys(vector)
                  difference = AguiHelper.first_difference(AguiHelper.strip_keys(expect.fetch("events"), keys),
                                                           AguiHelper.strip_keys(outcome[:events], keys), "events")

                  assert_nil difference, label
                end
              end
            end
          end
        end
      end
    end
  end
end
