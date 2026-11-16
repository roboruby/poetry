# frozen_string_literal: true

require "test_helper"

# installed by the poetry `screen-data-index` recipe. The screen route
# renders the block's furniture. That is the server's HTML, so no browser
# is needed: an integration test, which runs with `bin/rails test`.
class OrdersIndexTest < ActionDispatch::IntegrationTest
  test "the orders index renders the data-index screen" do
    get orders_path

    assert_response :success
    assert_select "h2", text: "Orders"
    assert_select "table", 1
    assert_includes response.body, "New order"
  end
end
