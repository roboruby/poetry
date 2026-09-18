# frozen_string_literal: true

# The architecture the family enforces by review, as checks (rake arch:check).
# Core is the root of the family: nothing here names a sibling gem or the
# host application, and lib reaches the components only through the
# registry and the base class.
root "."
source "app/**/*.rb", "lib/**/*.rb"

component :kernel, constants: %w[Poetry::Core::Component Poetry::Core::Wrapper::Component]
component :components, in: "app/components/**/*.rb",
                       except: ["app/components/poetry/core/component.rb", "app/components/poetry/core/wrapper/**/*"]
component :lib, in: "lib/**/*.rb"

lib.cannot_use :components, because: "lib reaches the components through the registry and the base class"
lib.cannot_reference_constants "Poetry::Ui", "Poetry::Charts", "Poetry::Agent", "Poetry::Extract",
                               "ApplicationController",
                               because: "core is the root of the family and never names the host"
components.cannot_reference_constants "Poetry::Ui", "Poetry::Charts", "Poetry::Agent", "Poetry::Extract",
                                      "ApplicationController",
                                      because: "core is the root of the family and never names the host"
no_cycles among: %i[lib components]
