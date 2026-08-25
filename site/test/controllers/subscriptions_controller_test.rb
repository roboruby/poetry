# frozen_string_literal: true

require "test_helper"

# The landing newsletter dialog's endpoint: the beehiiv call is server-side,
# so the controller owns validation, the honeypot, and failure mapping.
class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  # minitest 6 no longer bundles minitest/mock; swapping the singleton
  # method directly keeps the stub dependency-free.
  def with_stub(mod, name, replacement)
    original = mod.method(name)
    mod.define_singleton_method(name, replacement)
    yield
  ensure
    mod.define_singleton_method(name, original)
  end

  test "a valid email subscribes through the beehiiv client" do
    calls = []

    with_stub(Beehiiv, :api_key, -> { "test-key" }) do
      with_stub(Beehiiv, :subscribe, ->(email:, referring_site: nil) { calls << email; true }) do
        post "/subscriptions", params: { email: "reader@example.com" }, as: :json
      end
    end

    assert_response :success
    assert JSON.parse(response.body)["ok"]
    assert_equal ["reader@example.com"], calls
  end

  test "an invalid email is rejected before any API call" do
    with_stub(Beehiiv, :subscribe, ->(**) { flunk "the beehiiv client must not be called" }) do
      post "/subscriptions", params: { email: "not-an-email" }, as: :json
    end

    assert_response :unprocessable_entity
    payload = JSON.parse(response.body)
    refute payload["ok"]
    assert_includes payload["error"], "valid email"
  end

  test "a filled honeypot reports success without subscribing" do
    with_stub(Beehiiv, :subscribe, ->(**) { flunk "the beehiiv client must not be called" }) do
      post "/subscriptions", params: { email: "reader@example.com", website: "spam.example" }, as: :json
    end

    assert_response :success
    assert JSON.parse(response.body)["ok"]
  end

  test "a missing API key degrades to a clear service message" do
    with_stub(Beehiiv, :api_key, -> { nil }) do
      post "/subscriptions", params: { email: "reader@example.com" }, as: :json
    end

    assert_response :service_unavailable
    refute JSON.parse(response.body)["ok"]
  end

  test "a beehiiv failure maps to a retryable error" do
    with_stub(Beehiiv, :api_key, -> { "test-key" }) do
      with_stub(Beehiiv, :subscribe, ->(**) { raise Beehiiv::Error, "beehiiv responded 500" }) do
        post "/subscriptions", params: { email: "reader@example.com" }, as: :json
      end
    end

    assert_response :bad_gateway
    refute JSON.parse(response.body)["ok"]
  end

  test "the landing hero carries the subscribe dialog, poetry-native" do
    get "/"

    assert_response :success
    assert_includes response.body, "Subscribe to Ruby AI News for Updates"
    # The whole point: no beehiiv script, style, or iframe on the page.
    refute_includes response.body, "beehiiv.com"
    assert_includes response.body, 'data-controller="newsletter"'
    assert_includes response.body, 'action="/subscriptions"'
  end
end
