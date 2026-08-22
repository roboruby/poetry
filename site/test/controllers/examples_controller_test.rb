# frozen_string_literal: true

require "test_helper"

# The standalone example view: chrome-free single-example pages behind the
# "open standalone" link on every gallery frame.
class ExamplesControllerTest < ActionDispatch::IntegrationTest
  test "a component example renders standalone without the docs chrome" do
    get "/examples/components/badge/default"

    assert_response :success
    assert_includes response.body, "data-component"
    refute_includes response.body, "Toggle Sidebar", "docs chrome leaked into the standalone view"
    assert_includes response.body, 'name="robots" content="noindex"'
  end

  test "the data-dependent examples render standalone too" do
    first = ExamplesControllerTest.first_example("docs", "pagination")
    get "/examples/docs/pagination/#{first}"

    assert_response :success

    first = ExamplesControllerTest.first_example("demos", "interactive")
    get "/examples/demos/interactive/#{first}"

    assert_response :success
  end

  test "unknown pages and names 404, traversal never resolves" do
    get "/examples/components/badge/nope"

    assert_response :not_found

    get "/examples/components/never-shipped/default"

    assert_response :not_found
  end

  test "every gallery example links to its standalone view" do
    get "/components/badge"

    assert_includes response.body, "/examples/components/badge/"
    assert_includes response.body, "Open standalone"
  end

  def self.first_example(section, slug)
    Rails.root.join("app/views/examples/#{section}/#{slug}")
         .glob("_*.html.erb").map { |f| f.basename.to_s.delete_prefix("_").delete_suffix(".html.erb") }
         .sort_by { |name| [ name == "default" ? 0 : 1, name ] }.first
  end
end
