require "rack/cors"

# The site's assets answer with CORS headers: an MCP App's sandbox (a
# second origin, or an opaque frame in the inline mode) loads the plans
# app's module scripts and stylesheet cross-origin.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "/assets/*", headers: :any, methods: %i[get head options]
  end
end
