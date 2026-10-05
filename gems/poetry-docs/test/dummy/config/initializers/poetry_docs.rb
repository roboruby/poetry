# frozen_string_literal: true

# The dummy host's share of the engine's configuration: the Beehiiv key
# from its credentials, the way poetryui.com's former app held it, so the
# deploy repository can still build this host from the tree until the
# hostname moves to its real host.
Poetry::Docs.configure do |config|
  config.beehiiv_api_key = Rails.application.credentials.dig(:beehiiv, :api_key) if Rails.application.credentials.config.any?
end
