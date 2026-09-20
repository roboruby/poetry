# frozen_string_literal: true

# The architecture the family enforces by review, as checks (rake arch:check).
# agent depends on core and ui, never on charts or extract, and never
# names the host application.
root "."
source "app/**/*.rb", "lib/**/*.rb"

component :lib, in: "lib/**/*.rb"
component :app, in: "app/**/*.rb"

lib.cannot_reference_constants "Poetry::Charts", "Poetry::Extract", "ApplicationController",
                               because: "agent depends on core and ui and never names the host"
app.cannot_reference_constants "Poetry::Charts", "Poetry::Extract", "ApplicationController",
                               because: "agent depends on core and ui and never names the host"
