require "test_helper"

# The install-proof smoke: the home page must render a poetry-ui component
# and a finished poetry-charts SVG through the pipeline `rails g
# poetry:install --charts` wired - if any host seam breaks (pins, tokens,
# safelist, engine load), this page is where it surfaces first.
class DocsControllerTest < ActionDispatch::IntegrationTest
  test "the smoke page serves a poetry component and a server-rendered chart" do
    get root_url

    assert_response :success
    assert_select "[data-slot=button]"
    assert_select "svg[data-slot=chart-svg]" do
      assert_select "path[data-slot=chart-area]", 2
    end
    assert_select "[data-controller~=?]", "poetry--charts--tooltip"
  end

  test "the agent docs ride the mounted engine" do
    get "/poetry/llms.txt"

    assert_response :success
  end
end
