# frozen_string_literal: true

require "test_helper"

# The Islands library page: the install step, the contract, two live
# islands with their shells, the markdown mirror and the API pages.
class IslandPagesTest < ActionDispatch::IntegrationTest
  test "the library guide renders its sections and two live islands" do
    get "/libraries/island"

    assert_response :success
    assert_select "h1", "Islands"
    %w[what-it-is install contract modes form lifecycle check when-not].each { |id| assert_select "h2##{id}" }
    assert_select "[data-slot=island][data-poetry--island--island-import-value='poetry_docs/islands/clock']" \
                  "[data-poetry--island--island-mode-value=fill]", 1
    assert_select "[data-slot=island][data-poetry--island--island-mode-value=flow] > " \
                  "input[data-slot=island-input][name=count][value='3']", 1
    assert_select "[data-slot=island-shell]", 2
    assert_includes response.body, "poetry-island"
  end

  test "the islands are in the libraries list and the mirror carries the contract" do
    get "/libraries/island.md"

    assert_response :success
    assert_includes response.body, "poetry_island"
    assert_includes response.body, "mount(element, props)"
    assert_includes response.body, "island-import-unpinned"
  end

  test "the API reference documents the island gem's Ruby and JavaScript" do
    get "/api/poetry-island"

    assert_response :success
    assert_includes response.body, "Poetry::Island::ComponentsHelper"

    get "/api/poetry-island-controllers"

    assert_response :success
    assert_includes response.body, "poetry--island--island"
  end
end
