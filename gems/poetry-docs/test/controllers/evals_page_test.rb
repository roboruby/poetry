require "test_helper"

# The Evals page: every stored run, with its interval, and the page's
# Markdown twin.
class EvalsPageTest < ActionDispatch::IntegrationTest
  test "every stored run is a row with its counts, its share and its interval" do
    get "/evals"
    runs = Poetry::Docs::EvalLedger.read.fetch("runs")

    assert_response :success
    assert_select "h1", "Evals"
    assert_select "#runs ~ * tbody tr, section:has(#runs) tbody tr", runs.size
    first = css_select("section:has(#runs) tbody tr").first.css("td").map { |cell| cell.text.squish }

    assert_equal [ "2026-07-07", "31", "13", "18", "0", "42% (26% to 59%)", "83% / 67%" ], first
  end

  test "the page says what the numbers cannot, from the numbers themselves" do
    get "/evals"
    text = css_select("main").last.text.squish

    assert_includes text, "13 of the 15 intervals in the table contain one half"
    assert_includes text, "passed more of them than plain Tailwind's in 5 of 5"
    assert_includes text, "they passed more in 1 of 7"
    assert_includes text, "preferred Poetry on 1, 6 and 5 of 12 briefs"
    assert_includes text, "89% at the last; plain Tailwind's passed 62% and 62%"
  end

  test "the page has a Markdown twin with the same rows" do
    get "/evals.md"

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_includes response.body, "| `2026-07-07` | 31 | 13 | 18 | 0 | 42% (26% to 59%) | 83% / 67% |"
    assert_includes response.body, "| `2026-07-08` | 5 | 2 | 3 | 0 | 40% (12% to 77%) | not stored |"
    assert_includes response.body, "Poetry was preferred on 1, 6 and 5 of 12"
  end

  test "the page is served and linked from nowhere" do
    get "/evals"

    assert_response :success
    assert_select "a[href='/evals']", 0
    assert_select "link[rel=alternate][type='text/markdown'][href='/evals.md']"

    get "/docs"

    assert_select "a[href='/evals']", 0
    refute Poetry::Docs::DocsCatalog.all.any? { |entry| entry.slug == "evals" }, "no list of pages names it"
    refute_includes Poetry::Docs::SearchIndex::PATH.read, "/evals"
    refute_includes Poetry::Docs::DocsMarkdown.site_index, "/evals"

    get "/sitemap.xml"

    refute_includes response.body, "/evals"
  end
end
