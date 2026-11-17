# frozen_string_literal: true

require "test_helper"

# The page menu: every docs page with a Markdown twin offers it as a copy,
# as a link, and as an address handed to an assistant.
class PageMenuTest < ActionDispatch::IntegrationTest
  def menu
    css_select("main [data-page-menu]")
  end

  def test_a_page_with_a_markdown_twin_carries_the_menu_over_its_address
    get "/installation"

    assert_response :success
    assert_equal 1, menu.size
    assert_equal "/installation.md", menu.first["data-page-menu-url-value"]
    assert_equal "page-menu", menu.first["data-controller"]
    assert_select "main [data-page-menu] button[data-action='page-menu#copy']", text: /Copy page/
    assert_select "main [data-page-menu] [role=status][data-page-menu-target=status]"
    assert_select "link[rel=alternate][type='text/markdown'][href='/installation.md']"
  end

  def test_the_menu_links_the_markdown_and_hands_its_address_to_an_assistant
    get "/components/button"

    links = css_select("[data-page-menu] a[href]").to_h { |link| [ link.text.strip, link["href"] ] }
    address = CGI.escape("http://www.example.com/components/button.md")

    assert_equal "/components/button.md", links.fetch("View as Markdown")
    assert_includes links.fetch("Open in Claude"), "https://claude.ai/new?q=Read+#{address}"
    assert_includes links.fetch("Open in ChatGPT"), "https://chatgpt.com/?hints=search&q=Read+#{address}"
    assert(css_select("[data-page-menu] a[href]").all? { |link| link["target"] == "_blank" })
  end

  def test_the_address_the_menu_copies_serves_the_page_as_markdown
    get "/installation"
    address = menu.first["data-page-menu-url-value"]
    get address

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_operator response.body.size, :>, 200
  end

  def test_the_docs_home_copies_the_site_index
    get "/docs"

    assert_equal "/llms.txt", menu.first["data-page-menu-url-value"]
  end

  def test_a_page_with_no_markdown_twin_has_no_menu
    get "/"

    assert_response :success
    assert_empty css_select("[data-page-menu]")
  end

  def test_the_title_keeps_clear_of_the_menu
    get "/installation"

    assert_includes css_select("[data-page-menu]").first.parent["class"], "md:[&_h1]:pr-48"
  end
end
