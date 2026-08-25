# frozen_string_literal: true

# The marketing landing page at the site root. Renders outside the docs
# chrome with its own layout and the scoped brand-aurum token set.
class LandingController < ApplicationController
  layout "landing"

  def show
  end
end
