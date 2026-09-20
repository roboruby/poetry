require "test_helper"

# The numbers the site quotes about itself come from the registry, never
# from prose: the landing stats, the meta descriptions, and the library pages
# all read DocsCatalog, so a new component moves every count at once.
class CatalogCountsTest < ActionDispatch::IntegrationTest
  test "the landing page quotes the registry's component and chart counts" do
    get root_path

    assert_response :success
    assert_includes response.body, "#{DocsCatalog.components.size} components, #{DocsCatalog.charts.size} chart families"
    assert_select "[data-slot='stat-value']", text: DocsCatalog.components.size.to_s
  end

  test "the library pages quote the same component count" do
    get library_path("ui")

    assert_includes response.body, "#{DocsCatalog.components.size} accessible, themeable"

    get library_path("core")

    assert_includes response.body, "poetry-ui's #{DocsCatalog.components.size} components"
  end
end
