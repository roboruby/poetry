require "test_helper"

# The Citation and Sources pages, and the Markdown page's section on
# cited sources: a reply's marks and the list under it share one numbering.
class CitationsDocsTest < ActionDispatch::IntegrationTest
  test "the citation page renders marks named for their sources" do
    get "/components/citation"

    assert_response :success
    get "/examples/components/citation/default"

    assert_response :success
    assert_equal [ "Source 1: Fulfilment guide", "Source 2: Refund policy" ],
                 css_select("a[data-slot=citation]").map { |mark| mark["aria-label"] }
  end

  test "the sources page renders the list behind its count" do
    get "/components/sources"

    assert_response :success
    get "/examples/components/sources/default"

    assert_response :success
    assert_select "[data-slot=sources] button", text: /3 sources/
    assert_select "[data-slot=sources-item]", 3
  end

  test "a reply's marks and the list under it share their numbers" do
    get "/examples/components/sources/with_a_reply"

    assert_response :success
    assert_equal %w[1 2 1], css_select("[data-slot=markdown] [data-slot=citation]").map { |mark| mark.text }
    assert_equal %w[1 2], css_select("[data-slot=sources-item] [data-slot=citation]").map { |mark| mark.text }
    assert_equal css_select("[data-slot=markdown] a[data-slot=citation]").first["href"],
                 css_select("a[data-slot=sources-title]").first["href"]
  end

  test "the Markdown page explains cited sources" do
    get "/components/markdown"

    assert_response :success
    assert_select "h2#cited-sources", 1
    assert_includes response.body, "Poetry::Ui::Citations.mark"
  end
end
