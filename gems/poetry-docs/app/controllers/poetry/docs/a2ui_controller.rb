# frozen_string_literal: true

# The A2UI catalog: the component registry projected as an A2UI catalog
# document, served where an agent (or a middleware fetching the frontend's
# catalog at boot) can read it: /a2ui/v1_0/catalog.json (also
# /a2ui/catalog.json) for v1.0 agents, /a2ui/v0_9/catalog.json for v0.9
# ones. Static per process - the registry is a committed file.
module Poetry
  module Docs
    class A2uiController < ApplicationController
      def catalog
        expires_in 1.hour, public: true
        render json: self.class.document(params[:version] == "v0.9" ? "v0.9" : "1.0")
      end

      def self.document(version = "1.0")
        @catalog ||= Poetry::Agent::A2UI::Catalog.from_registry(Poetry::Ui.root)
        @catalog.to_h(version: version)
      end
    end
  end
end
