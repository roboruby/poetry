# frozen_string_literal: true

# The WebMCP smoke gate: Google's webmcp-evals runs eval/webmcp/poetry-evals.json
# against a booted docs site in a real Chrome (--enable-features=WebMCP),
# executing every tool the /webmcp page registers with no model involved.
# Boot the site first (bin/dev, or bin/rails server); point WEBMCP_URL at it
# when it is not on 127.0.0.1:3000, and CHROME_CHANNEL at a channel other
# than stable. The suite's names are kept honest by test/webmcp_smoke_suite_test.rb.
namespace :webmcp do
  desc "Run the WebMCP smoke suite against a booted docs site (WEBMCP_URL, CHROME_CHANNEL)"
  task :smoke do
    url = ENV.fetch("WEBMCP_URL", "http://127.0.0.1:3000").chomp("/")
    channel = ENV.fetch("CHROME_CHANNEL", "chrome")
    suite = Rails.root.join("eval/webmcp/poetry-evals.json").to_s
    command = ["npx", "-y", "webmcp-evals@0.0.4", "smoke", "-u", "#{url}/webmcp", "-e", suite,
               "--chrome-channel", channel, "-v"]
    puts command.join(" ")
    system(*command) || abort("webmcp:smoke failed")
  end
end
