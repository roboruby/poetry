# frozen_string_literal: true

require "rails/engine"

module Poetry
  module JumpstartPro
    # A minimal engine so Rails discovers the install generator under
    # lib/generators/. No runtime views or helpers of its own - the ported
    # screens are copied into the HOST's app/views by the installer, where
    # they render against poetry-ui's helpers and the host's Jumpstart routes.
    class Engine < ::Rails::Engine
      isolate_namespace Poetry::JumpstartPro
    end
  end
end
