# frozen_string_literal: true

require_relative "agui_contract"

# The AG-UI 1.0 contract table the enforcement walker reads, generated from
# the vendored schema (test/fixtures/agui/1.0/schema.json) and committed.
namespace :agui do
  schema = File.expand_path("../test/fixtures/agui/1.0/schema.json", __dir__)
  contract = File.expand_path("../config/agui/contract-1.0.json", __dir__)

  desc "Regenerate config/agui/contract-1.0.json from the vendored AG-UI 1.0 schema"
  task :contract do
    FileUtils.mkdir_p(File.dirname(contract))
    File.write(contract, AguiContract.generate(schema))
    puts "agui:contract: wrote #{File.basename(contract)} (#{File.size(contract)} bytes)"
  end

  desc "Fail when the committed AG-UI contract table differs from a fresh generation"
  task :verify do
    fresh = AguiContract.generate(schema)
    abort "agui:verify: #{contract} is missing - run rake agui:contract" unless File.exist?(contract)
    unless File.read(contract) == fresh
      abort "agui:verify: the contract table is stale - run rake agui:contract and commit"
    end

    puts "agui:verify: the contract table matches the vendored schema"
  end
end
