# frozen_string_literal: true

# The architecture the family enforces by review, as checks (rake arch:check).
# charts depends on core, and on ui only through the registry: no chart
# names a ui component class.
root "."
source "app/**/*.rb", "lib/**/*.rb"

component :components, in: "app/components/**/*.rb"
component :lib, in: "lib/**/*.rb"

lib.cannot_use :components, because: "lib reaches the components through the registry"
lib.cannot_reference_constants "Poetry::Ui", "Poetry::Agent", "Poetry::Extract", "ApplicationController",
                               because: "charts depends on core, on ui through the registry only, never the host"
components.cannot_reference_constants "Poetry::Ui", "Poetry::Agent", "Poetry::Extract", "ApplicationController",
                                      because: "charts depends on core, on ui through the registry only, never the host"
no_cycles among: %i[lib components]
