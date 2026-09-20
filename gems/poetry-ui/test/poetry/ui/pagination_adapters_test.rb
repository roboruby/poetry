# frozen_string_literal: true

require "test_helper"
require "kaminari"
require "pagy"
# Pagy::Request has no autoload entry (upstream gap; real hosts reach it
# through the pagy() controller path) - direct construction requires it.
require "pagy/classes/request"
require "will_paginate"
require "will_paginate/view_helpers/action_view"
require "will_paginate/collection"

# The generated adapter code, loaded exactly as a host would own it.
TEMPLATES_DIR = File.expand_path("../../../lib/generators/poetry/pagination/templates", __dir__)
load File.join(TEMPLATES_DIR, "poetry_pagy_helper.rb")
load File.join(TEMPLATES_DIR, "poetry_link_renderer.rb")

# A real host controller: every adapter renders inside an authentic
# request (will_paginate's url(page) and pagy's Request need one).
class PaginationHostController < ApplicationController
  helper ::PoetryPagyHelper

  def kaminari_page
    collection = Kaminari.paginate_array((1..50).to_a).page(params.fetch(:page, 3)).per(5)
    render inline: "<%= paginate collection %>", locals: { collection: collection }, layout: false
  end

  def kaminari_options_page
    collection = Kaminari.paginate_array((1..100).to_a).page(5).per(5)
    render inline: "<%= paginate collection, siblings: 2 %>",
           locals: { collection: collection }, layout: false
  end

  def pagy_page
    pagy = Pagy::Offset.new(count: params.fetch(:count, 50).to_i, page: 3, limit: 5,
                            request: Pagy::Request.new(request: request))
    render inline: "<%= poetry_pagy_nav(pagy) %>", locals: { pagy: pagy }, layout: false
  end

  def will_paginate_page
    collection = WillPaginate::Collection.create(3, 5, 50) { |pager| pager.replace((1..5).to_a) }
    render inline: "<%= will_paginate collection, renderer: PoetryLinkRenderer %>",
           locals: { collection: collection }, layout: false
  end
end

module Poetry
  module Ui
    # The generated pagination adapters, end-to-end through real requests.
    class PaginationAdaptersTest < ActionDispatch::IntegrationTest
      DUMMY_KAMINARI_VIEW = File.expand_path("../../dummy/app/views/kaminari", __dir__)

      # The /phost/* routes live permanently in test/dummy/config/routes.rb:
      # runtime route mutation proved unreliable here (require-time mutation
      # trips the Rails 8 lazy route set into a mid-suite reload that strands
      # the engines' autoloaded constants; setup-time additive draws get
      # wiped by later route reloads). Permanent routes survive any reload.

      # The kaminari override template is COMMITTED at
      # test/dummy/app/views/kaminari/_paginator.html.erb rather than copied
      # in at test time: with reloading enabled (the dummy sets no
      # enable_reloading), a view-file write mid-suite triggers a full app
      # reload that detaches the engines' autoloaded constants from every
      # already-defined test class. The drift guard below keeps the
      # committed copy byte-identical to the generator template.
      def test_kaminari_dummy_template_matches_the_generator_template
        assert FileUtils.identical?(
          File.join(TEMPLATES_DIR, "kaminari_paginator.html.erb"),
          File.join(DUMMY_KAMINARI_VIEW, "_paginator.html.erb")
        ), "test/dummy/app/views/kaminari/_paginator.html.erb drifted from " \
           "the generator template - re-copy it"
      end

      def test_kaminari_paginate_renders_poetry_pagination
        get "/phost/kaminari"

        assert_response :success
        assert_includes response.body, 'data-slot="pagination"', "the poetry nav renders"
        assert_includes response.body, 'aria-current="page"'
        assert_match(/href="[^"]*page=4[^"]*"/, response.body, "next URL from page_url_for")
        assert_match(%r{href="/phost/kaminari"}, response.body, "page 1 stays the canonical param-less URL")
      end

      def test_kaminari_passes_poetry_options_through_paginate
        get "/phost/kaminari_options"

        assert_response :success
        assert_match(/>\s*3\s*</, response.body)
        assert_match(/>\s*7\s*</, response.body, "siblings: 2 flows from paginate to poetry")
      end

      def test_pagy_nav_renders_poetry_pagination
        get "/phost/pagy"

        assert_response :success
        assert_includes response.body, 'data-slot="pagination"'
        assert_includes response.body, 'aria-current="page"'
        assert_match(/href="[^"]*page=4[^"]*"/, response.body, "next URL from pagy.page_url")
      end

      def test_pagy_nav_renders_nothing_at_a_single_page
        get "/phost/pagy", params: { count: 3 }

        assert_response :success
        refute_includes response.body, "data-slot", "mirrors the nil-at-one-page behavior"
      end

      def test_will_paginate_renderer_emits_poetry_pagination
        get "/phost/will_paginate"

        assert_response :success
        assert_includes response.body, 'data-slot="pagination"'
        assert_includes response.body, 'aria-current="page"'
        assert_match(/href="[^"]*page=4[^"]*"/, response.body, "URLs from the inherited url(page)")
      end
    end
  end
end
