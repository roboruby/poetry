# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "stringio"

module Poetry
  module Extract
    class RunnerTest < Minitest::Test
      DESIGN_MD = <<~MD
        ---
        version: alpha
        name: Example
        colors:
          primary: "#635bff"
        ---

        # Example

        ## Overview

        A design system.
      MD

      FakeComposer = Struct.new(:result) do
        def design_md(**) = result
      end

      def signals
        Signals.new(styleguide: { "mode" => "light" }, brand: nil, screenshot_url: nil, markdown: "")
      end

      def test_run_writes_the_three_artifacts_and_prints_the_import_handoff
        Dir.mktmpdir do |dir|
          io = StringIO.new
          out = Runner.run!("https://www.Example.com/pricing", out_root: dir,
                                                               signals: signals,
                                                               composer: FakeComposer.new(DESIGN_MD.strip),
                                                               io: io)

          assert_equal File.join(dir, "example.com"), out
          assert_equal "#{DESIGN_MD.strip}\n", File.read(File.join(out, "DESIGN.md"))
          assert_includes File.read(File.join(out, "theme.tailwind.css")), "@theme inline {"
          assert_includes File.read(File.join(out, "tokens.css")), "/* example.com — design tokens"
          assert_includes io.string, %(poetry:design:import[#{out}/DESIGN.md])
        end
      end

      def test_invalid_domain_and_empty_compose_raise
        assert_raises(Error) { Runner.run!("https:///", out_root: "unused", signals: signals) }
        Dir.mktmpdir do |dir|
          assert_raises(Error) do
            Runner.run!("example.com", out_root: dir, signals: signals, composer: FakeComposer.new(""))
          end
        end
      end
    end
  end
end
