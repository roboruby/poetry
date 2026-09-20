require "test_helper"

# Every page carries the same head metadata: a description, a canonical URL
# on the request host, and Open Graph + Twitter tags with an absolute image.
class MetaTagsTest < ActionDispatch::IntegrationTest
  test "the landing page carries canonical, Open Graph and Twitter metadata" do
    get root_path

    assert_response :success
    assert_select "title", PageMetaHelper::SITE_TITLE
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/"
    assert_select "meta[property='og:url'][content=?]", "http://www.example.com/"
    assert_select "meta[property='og:type'][content=website]"
    assert_select "meta[property='og:image'][content^=?]", "http://www.example.com/assets/landing-og-"
    assert_select "meta[property='og:image:width'][content=1200]"
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
    assert_select "meta[name=description][content*=?]", "#{DocsCatalog.components.size} components"
  end

  test "docs pages take their title and description from the page and their canonical from the request" do
    get component_path("button")

    assert_response :success
    assert_select "title", /Button — poetry/
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/components/button"
    assert_select "meta[property='og:url'][content=?]", "http://www.example.com/components/button"
    assert_select "meta[property='og:type'][content=article]"
    assert_select "meta[property='og:title'][content*=Button]"
    assert_select "meta[name=description][content=?]", DocsCatalog.components.find { |e| e.slug == "button" }.description
  end

  test "a page without an entry still gets the site description" do
    get introduction_path

    assert_response :success
    assert_select "meta[name=description][content]" do |nodes|
      assert nodes.first["content"].present?
    end
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/docs"
  end
end
