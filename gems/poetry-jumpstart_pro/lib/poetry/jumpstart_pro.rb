# frozen_string_literal: true

require_relative "jumpstart_pro/version"
require_relative "jumpstart_pro/stylesheets"
require_relative "jumpstart_pro/test_edits"

module Poetry
  # poetry-jumpstart_pro: re-skins a Jumpstart Pro app's views with poetry
  # components. It ships ONLY poetry-native recreations of the screens (never
  # Jumpstart's proprietary source) and installs them as host overrides in
  # app/views/, which Rails resolves ahead of the Jumpstart engine's originals.
  #
  # @example Check whether a view category is installable
  #   Poetry::JumpstartPro::CATEGORIES.include?("billing") # => true
  module JumpstartPro
    # The view categories this gem can install, in install order. Each maps
    # to a templates/<category>/ tree mirroring the host's app/views.
    #   auth          - sign in and up, password reset, two-factor, sudo, OAuth buttons, form errors
    #   shell         - app-shell chrome (navbar and its native variant, menus, notifications, flash, footer)
    #   accounts      - account settings, team members, invitations, transfer, the settings navigation
    #   users         - mention chip, agreements, connected accounts, referrals, backup codes
    #   api_tokens    - personal API token index/new/edit/show/form
    #   notifications - notifications index + dropdown frame + row partial
    #   announcements - changelog index/show + row partial
    #   checkouts     - the checkout page (the processor forms stay Jumpstart's)
    #   public        - landing, about, privacy, terms
    #   dashboard     - the signed-in home
    #   errors        - the 404, 500 and generic error pages
    #   billing       - subscriptions, payment methods, charges, pricing/show
    #   madmin        - admin dashboard + array-field form/index/show partials
    # NOTE: pricing/show is folded into `billing` (it renders billing's plan
    # partial + pricing_cta), so it is not a standalone category.
    CATEGORIES = %w[auth shell accounts users api_tokens notifications announcements
                    checkouts public dashboard errors billing madmin].freeze

    # @return [String] the absolute path to the gem's checkout root
    def self.root
      File.expand_path("../..", __dir__)
    end
  end
end

require_relative "jumpstart_pro/engine" if defined?(Rails::Engine)
