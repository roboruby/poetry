# frozen_string_literal: true

# Serves the effects' previews to the browser rig (rake test:accessibility, test:visual).
class PreviewsController < ApplicationController
  include ViewComponent::PreviewActions
end
