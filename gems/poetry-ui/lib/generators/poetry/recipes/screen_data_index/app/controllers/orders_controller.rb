# frozen_string_literal: true

# installed by the poetry `screen-data-index` recipe - this file is yours:
# edit freely. Wire the route yourself (one line, so your routes.rb is
# never touched by an installer):
#
#   resources :orders, only: :index
#
# The view renders the data-index block (installed alongside at
# app/views/blocks/_data_index.html.erb) with its sample rows; replace the
# block's static table with your records as you adapt it - the markup is
# yours too.
class OrdersController < ApplicationController
  def index; end
end
