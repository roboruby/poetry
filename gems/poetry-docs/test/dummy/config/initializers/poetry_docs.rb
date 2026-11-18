# frozen_string_literal: true

# The dummy host's share of the engine's configuration: the Beehiiv key
# from its credentials, the way poetryui.com's former app held it, so the
# deploy repository can still build this host from the tree until the
# hostname moves to its real host.
Poetry::Docs.configure do |config|
  config.beehiiv_api_key = Rails.application.credentials.dig(:beehiiv, :api_key) if Rails.application.credentials.config.any?
  # The community registry's build output, to see the Community pages
  # here: POETRY_COMMUNITY_REGISTRY=../../../../../poetry-ports/public/r
  config.community_registry = ENV["POETRY_COMMUNITY_REGISTRY"].presence
  # The address its saved demos are served from, to see them run on an
  # item's page: POETRY_COMMUNITY_DEMOS=http://127.0.0.1:4120
  config.community_demos = ENV["POETRY_COMMUNITY_DEMOS"].presence
end
