# frozen_string_literal: true

# The WebMCP smoke gate: Google's webmcp-evals runs eval/webmcp/poetry-evals.json
# against a booted docs host in a real Chrome (--enable-features=WebMCP),
# executing every tool the /webmcp page registers with no model involved.
# Boot the dummy host first (bin/dev); point WEBMCP_URL at it when it is
# not on 127.0.0.1:4110, and CHROME_CHANNEL at a channel other than
# stable. The suite's names are kept honest by test/webmcp_smoke_suite_test.rb.
namespace :poetry_docs do
  namespace :webmcp do
    desc "Run the WebMCP smoke suite against a booted docs host (WEBMCP_URL, CHROME_CHANNEL)"
    task :smoke do
      url = ENV.fetch("WEBMCP_URL", "http://127.0.0.1:4110").chomp("/")
      channel = ENV.fetch("CHROME_CHANNEL", "chrome")
      suite = Poetry::Docs.root.join("eval/webmcp/poetry-evals.json").to_s
      command = [ "npx", "-y", "webmcp-evals@0.0.4", "smoke", "-u", "#{url}/webmcp", "-e", suite,
                 "--chrome-channel", channel, "-v" ]
      puts command.join(" ")
      system(*command) || abort("poetry_docs:webmcp:smoke failed")
    end
  end
end
