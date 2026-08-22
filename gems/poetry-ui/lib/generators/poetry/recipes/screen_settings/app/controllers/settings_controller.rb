# frozen_string_literal: true

# installed by the poetry `screen-settings` recipe - this file is yours:
# edit freely. Wire the route yourself (one line, so your routes.rb is
# never touched by an installer):
#
#   resource :settings, only: :show
#
# The view composes the page-header, section-card, and destructive-panel
# blocks (installed alongside under app/views/blocks/); adapt their copy
# and wire the actions to your models as you go.
class SettingsController < ApplicationController
  def show; end
end
