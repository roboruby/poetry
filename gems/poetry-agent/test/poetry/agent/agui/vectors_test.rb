# frozen_string_literal: true

require "test_helper"
require "agui_helper"

module Poetry
  module Agent
    module AGUI
      # The reference client's own unit-test vectors for the compatibility
      # boundary, chunk expansion and verification
      # (test/fixtures/agui/1.0/vectors), each events in and an outcome out,
      # run through a fresh strict pipeline. The apply vectors run in
      # ApplyVectorsTest.
      class VectorsTest < Minitest::Test
        # Vector key ("file > name") to why Poetry answers it differently; the
        # list only shrinks.
        DIVERGENCES = {
          "chunks--transform-roles > transformChunks with roles > should preserve role 'tool' when transforming " \
          "text message chunks [tool]" =>
            "a role outside TextMessageRole is a member of a closed set added later: Poetry strips it, as " \
            "processing.mdx requires, where the reference rejects it (its admitted gap)"
        }.freeze

        Dir[File.join(AguiHelper::ROOT, "vectors", "*.json")].each do |path|
          file = File.basename(path, ".json")
          next if file.start_with?("apply--")

          JSON.parse(File.read(path)).fetch("vectors").each_with_index do |vector, index|
            define_method("test_#{file.tr("-", "_")}_#{index}") do
              key = "#{file} > #{vector["name"]}"
              if DIVERGENCES.key?(key)
                outcome = AguiHelper.run_pipeline(vector.fetch("input"))

                assert_nil outcome[:error], "#{key} matches the reference now: drop it from DIVERGENCES"
                next
              end

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
