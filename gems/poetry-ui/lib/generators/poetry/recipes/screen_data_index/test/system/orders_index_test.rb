# frozen_string_literal: true

require "application_system_test_case"

# installed by the poetry `screen-data-index` recipe. Server-render
# assertions only - no JS driver required; the test proves the screen
# route renders the block's furniture.
class OrdersIndexTest < ApplicationSystemTestCase
  test "the orders index renders the data-index screen" do
    visit orders_path

    assert_text "Orders"
    assert_selector "table"
    assert_text "New order"
  end
end
