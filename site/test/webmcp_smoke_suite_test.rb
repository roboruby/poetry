require "test_helper"

# The committed smoke suite (bin/rails webmcp:smoke runs it through Google's
# webmcp-evals in a real Chrome) must name tools the /webmcp page actually
# registers: every functionName is a component tool (poetry.{instance}.{tool}
# from an opted-in root's payload) or the declarative form's toolname, and
# every registered tool has a case.
class WebmcpSmokeSuiteTest < ActionDispatch::IntegrationTest
  test "the smoke suite and the WebMCP page agree on the tool roster" do
    suite = JSON.parse(Rails.root.join("eval/webmcp/poetry-evals.json").read)
    get webmcp_url

    assert_response :success
    doc = Nokogiri::HTML5(response.body)
    registered = doc.css("[data-poetry--agent--webmcp-name-value]").flat_map do |root|
      instance = root["data-poetry--agent--webmcp-name-value"]
      JSON.parse(root["data-poetry--agent--webmcp-tools-value"]).map { |tool| "poetry.#{instance}.#{tool["name"]}" }
    end + doc.css("form[toolname]").map { |form| form["toolname"] }
    called = suite.flat_map { |c| c.fetch("expectedCall").map { |call| call.fetch("functionName") } }.uniq

    assert_empty called - registered, "the suite calls tools the page does not register"
    assert_empty registered - called, "registered tools without a smoke case"
  end
end
