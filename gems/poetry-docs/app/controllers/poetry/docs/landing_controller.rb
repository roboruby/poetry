# frozen_string_literal: true

# The marketing landing page at the site root. Renders outside the docs
# chrome with its own layout and the scoped brand-aurum token set.
module Poetry
  module Docs
    class LandingController < ApplicationController
      layout "poetry/docs/landing"

      def show
      end
    end
  end
end
