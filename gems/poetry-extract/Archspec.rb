# frozen_string_literal: true

# The architecture the family enforces by review, as checks (rake arch:check).
# extract depends on core alone.
root "."
source "lib/**/*.rb"

component :lib, in: "lib/**/*.rb"

lib.cannot_reference_constants "Poetry::Ui", "Poetry::Charts", "Poetry::Agent", "ApplicationController",
                               because: "extract depends on core alone and never names the host"
