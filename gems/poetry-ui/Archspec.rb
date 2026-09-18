# frozen_string_literal: true

# The architecture the family enforces by review, as checks (rake arch:check).
# ui depends on core alone. lib reaches the components only through the
# registry; the test helpers under lib/poetry/ui/testing drive components
# by name and may name them; the generators are install tooling nothing
# in a component depends on.
root "."
source "app/**/*.rb", "lib/**/*.rb"

component :components, in: "app/components/**/*.rb"
component :lib, in: "lib/**/*.rb", except: ["lib/generators/**/*", "lib/poetry/ui/testing/**/*"]
component :testing, in: "lib/poetry/ui/testing/**/*.rb"
component :generators, in: "lib/generators/**/*.rb"

lib.cannot_use :components, because: "lib reaches the components through the registry"
components.cannot_use :generators, because: "a component never depends on the install tooling"
lib.cannot_reference_constants "Poetry::Charts", "Poetry::Agent", "ApplicationController",
                               because: "ui depends on core alone and never names the host"
components.cannot_reference_constants "Poetry::Charts", "Poetry::Agent", "ApplicationController",
                                      because: "ui depends on core alone and never names the host"
no_cycles among: %i[lib components]
