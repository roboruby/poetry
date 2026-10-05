module Poetry
  module Docs
    # The engine's own base: the docs' layout, never the host's, and no host
    # filters. Every docs controller inherits from here.
    class ApplicationController < ActionController::Base
      layout "poetry/docs/application"
      stale_when_importmap_changes
    end
  end
end
