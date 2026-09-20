# frozen_string_literal: true

# The architecture the family enforces by review, as checks (rake arch:check).
# simple_form depends on core and ui.
root "."
source "lib/**/*.rb"

component :lib, in: "lib/**/*.rb"

lib.cannot_reference_constants "Poetry::Charts", "Poetry::Agent", "Poetry::Extract", "ApplicationController",
                               because: "simple_form depends on core and ui and never names the host"
