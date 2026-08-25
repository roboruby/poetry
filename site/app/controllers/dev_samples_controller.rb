# frozen_string_literal: true

# Development-only: renders the landing page's code sample for real, so
# edits to compose_example.erb.sample can be seen, not just read. Routed
# only in development (config/routes.rb).
class DevSamplesController < ApplicationController
  layout false

  def card
    @sample = render_to_string(inline: Rails.root.join("app/views/landing/compose_example.erb.sample").read)
  end
end
