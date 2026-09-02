# frozen_string_literal: true

# The A2UI catalog: the component registry projected as an A2UI v1.0
# catalog document, served where an agent (or a middleware fetching the
# frontend's catalog at boot) can read it. Static per process - the
# registry is a committed file.
class A2uiController < ApplicationController
  def catalog
    expires_in 1.hour, public: true
    render json: self.class.document
  end

  def self.document
    @document ||= Poetry::Agent::A2UI::Catalog.from_registry(Poetry::Ui.root).to_h
  end
end
