# frozen_string_literal: true

require "test_helper"
require "rake"

module Poetry
  module Ui
    # The cold-start prompt: one text for `poetry:prompt` and the docs
    # site, carrying the usage rules every llms.txt prints and ending on
    # check-LAST.
    class PromptTest < ActiveSupport::TestCase
      def test_the_prompt_verifies_the_install_routes_to_the_surfaces_and_ends_on_check
        prompt = Prompt.cold_start

        assert_includes prompt, "bin/rails poetry:verify"
        assert_includes prompt, "bin/rails g poetry:skill"
        assert_includes prompt, "bin/rails g poetry:editor"
        assert_includes prompt, "/poetry/llms-full.txt"
        Poetry::Core::LlmsText::USAGE_RULES.each { |rule| assert_includes prompt, "- #{rule}" }
        assert_match(%r{\A5\. Check comes LAST: run `bin/rails poetry:check` as your final action}, prompt.lines.last)
      end

      def test_the_rake_task_prints_the_prompt
        output, = capture_io do
          Rake.with_application do |rake|
            load File.expand_path("../../../lib/tasks/poetry/prompt.rake", __dir__)
            rake["poetry:prompt"].invoke
          end
        end

        assert_equal Prompt.cold_start, output
      end
    end
  end
end
