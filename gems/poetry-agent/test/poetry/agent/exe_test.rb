# frozen_string_literal: true

require "test_helper"
require "open3"
require "json"

module Poetry
  module Agent
    # The poetry-agent executable, driven as a real subprocess exactly as
    # .mcp.json does. It must carry the FULL check catalog: a blocks-gate
    # run (2026-07-09) once shipped a render crash the icon-membership tier
    # existed to prevent, because an exe launched the server without icon
    # names - every MCP check ran shape-only. One exe, one gem, one surface.
    class ExeTest < Minitest::Test
      def call_exe(requests)
        stdout, _stderr, status = Open3.capture3(
          { "BUNDLE_GEMFILE" => Poetry::Agent.root.join("Gemfile").to_s },
          # The exe file itself (a path checkout has no RubyGems binstub; an
          # installed gem does, and .mcp.json's `bundle exec poetry-agent`
          # resolves through it).
          "bundle", "exec", "ruby", Poetry::Agent.root.join("exe/poetry-agent").to_s,
          stdin_data: "#{requests.map { |request| JSON.generate(request) }.join("\n")}\n",
          chdir: Poetry::Agent.root.to_s
        )

        assert_predicate status, :success?, "poetry-agent exited #{status.exitstatus}"
        stdout.lines.map { |line| JSON.parse(line) }
      end

      def check_request(id, source)
        { "jsonrpc" => "2.0", "id" => id, "method" => "tools/call",
          "params" => { "name" => "check", "arguments" => { "source" => source } } }
      end

      def test_the_resolving_exe_serves_the_skills_at_runtime
        requests = [
          { "jsonrpc" => "2.0", "id" => 1, "method" => "tools/call",
            "params" => { "name" => "get_skill",
                          "arguments" => { "name" => "poetry-design" } } },
          { "jsonrpc" => "2.0", "id" => 2, "method" => "tools/call",
            "params" => { "name" => "get_skill",
                          "arguments" => { "name" => "poetry-component" } } }
        ]
        design, component = call_exe(requests).map { |reply| reply.dig("result", "content", 0, "text") }

        assert_includes design, "poetry-design",
                        "the design skill reaches MCP-only hosts"
        assert_includes design, "references/audit.md", "the file index rides along"
        assert_includes component, "poetry-component",
                        "the authoring skill reaches MCP-only hosts"
        assert_includes component, "references/anatomy.md", "the file index rides along"
      end

      def test_the_resolving_exe_checks_icon_membership_and_helper_arity
        replies = call_exe([
                             check_request(1, %(<%= poetry_icon(name: :filter) %>)),
                             check_request(2, %(<%= poetry_link "Meridian", href: "/" %>))
                           ])
        texts = replies.to_h { |reply| [reply["id"], reply.dig("result", "content", 0, "text")] }

        assert_match(/FAIL/, texts[1])
        assert_match(/not in the icon set/, texts[1],
                     "membership, not just shape - the data_table :filter crash class")
        assert_match(/FAIL/, texts[2])
        assert_match(/no positional arguments/, texts[2],
                     "helper arity reaches the boot-free path - the site_nav crash class")
      end
    end
  end
end
