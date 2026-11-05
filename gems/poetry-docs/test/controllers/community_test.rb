require "test_helper"
require "tmpdir"

# The Community pages: the index (a catalog page) and a page per item,
# both read from the community registry's index. The fixture registry
# holds a port with a component's facts and a screenshot, an original
# block, and a bundle that credits two origins.
class CommunityTest < ActionDispatch::IntegrationTest
  FIXTURE = Poetry::Docs.root.join("test/fixtures/files/community")

  def with_registry(dir = FIXTURE)
    Poetry::Docs.config.community_registry = dir
    yield
  ensure
    Poetry::Docs.config.community_registry = nil
  end

  test "the index lists every item the registry describes, each linked to its page" do
    with_registry do
      get community_path

      assert_response :success
      assert_select "h1", "Community"
      assert_select "[data-slot=card]", 3
      assert_select "a[href=?]", "/community/note-card", text: "Note card"
      assert_select "a[href=?]", "/community/quote-wall", text: "Quote wall"
      assert_select "img[src=?][width='672'][height='88']", "/r/community/screenshots/note-card.webp"
      assert_select "pre", text: %r{bin/rails g poetry:add @poetry/<name>}
      assert_no_match(/Not A Name/, response.body, "an entry whose name is not a registry name is left out")
    end
  end

  test "the index says so when the host serves no community registry" do
    get community_path

    assert_response :success
    assert_select "[data-slot=card]", 0
    assert_select "p", /serves no community registry/
  end

  test "the items add no headings to the search index, which is the same on every host" do
    headings = lambda do
      get community_path
      # What SearchIndex reads: stable ids only, never a component's generated one.
      Nokogiri::HTML5(response.body).css("main h2[id], main h3[id]").map { |heading| heading[:id] }
                                    .reject { |id| id.start_with?("poetry-") }
    end
    bare = headings.call

    with_registry { assert_equal bare, headings.call }
    assert_equal %w[how-it-works reviewed-not-audited items], bare
  end

  test "a port's page shows its install, screenshot, example, options, slots, rules and origin" do
    with_registry do
      get community_item_path("note-card")

      assert_response :success
      assert_select "title", /Note card — poetry/
      assert_select "meta[name=description][content=?]", "A note in a card, with its author and a pin."
      assert_select "pre", text: %r{bin/rails g poetry:add @poetry/note-card}
      assert_select "figure img[src=?][alt=?]", "/r/community/screenshots/note-card.webp", "Note card, as its demo renders"
      assert_select "span", /version 44204791b5d3/
      assert_select "pre", text: /community_note_card\(body: "Ship it", author: "Ada"\)/
      assert_select "code", "community_note_card"

      assert_select "section:has(#options) tbody tr", 3
      assert_select "section:has(#options) tbody tr:first-child td", /body:/, "the required option leads"
      assert_select "section:has(#options) tbody tr:first-child [data-slot=badge]", "required"
      assert_select "section:has(#options) td", "false"
      assert_select "section:has(#style-axes) td", ":default, :sm"
      assert_select "section:has(#slots) td", "with_pin"
      assert_select "section:has(#usage-rules) li", /never renders HTML/

      assert_select "section:has(#install) li", "app/components/community/note_card/style.rb"
      assert_select "section:has(#install) [data-slot=badge]", "button"
      assert_select "section:has(#install) p", /Restart a running server/
      assert_select "section:has(#origin) a[href=?]", "https://acme.dev/r/note.json", text: "@acme/note"
      assert_select "section:has(#origin) a[href=?]", "https://github.com/acme/ui"
      assert_select "section:has(#origin)", /License:\s+MIT\.\s+Copyright \(c\) 2025 Acme/
      assert_no_match(/Permission is hereby granted/, response.body, "the license text lands in the app's notices, not on the page")
    end
  end

  test "an original block's page shows what the index says and nothing it does not" do
    with_registry do
      get community_item_path("quote-wall")

      assert_response :success
      assert_select "[data-slot=badge]", "Block"
      assert_select "pre", text: %r{render "blocks/quote_wall"}
      assert_select "section:has(#origin) p", /An original community item/
      assert_select "figure", 0
      assert_select "#options", 0
      assert_select "#slots", 0
    end
  end

  test "a bundle's page credits every origin, links only web addresses and names its gems" do
    with_registry do
      get community_item_path("editor-bundle")

      assert_response :success
      assert_select "section:has(#origin) li", 2
      assert_select "section:has(#origin) a[href=?]", "https://www.npmjs.com/package/@tiptap/react"
      assert_select "a[href^='javascript:']", 0
      assert_select "section:has(#origin)", %r{@react/react}
      assert_select "section:has(#install) [data-slot=badge]", "poetry-island"
    end
  end

  test "an unknown item, and any item on a host with no registry, is a 404" do
    with_registry do
      get "/community/absent"

      assert_response :not_found
    end
    get "/community/note-card"

    assert_response :not_found
  end

  test "the screenshot serves beside the index, and nothing else in the directory does" do
    with_registry do
      get "/r/community/screenshots/note-card.webp"

      assert_response :success
      assert_equal "image/webp", response.media_type
      assert_equal FIXTURE.join("screenshots/note-card.webp").binread, response.body
      get "/r/community/screenshots/absent.webp"

      assert_response :not_found
      get "/r/community/screenshots/registry.json"

      assert_response :not_found
    end
    get "/r/community/screenshots/note-card.webp"

    assert_response :not_found
  end

  test "the sitemap lists the item pages a host serves, and none where it serves no registry" do
    with_registry do
      get "/sitemap.xml"

      assert_includes response.body, "/community/note-card</loc>"
      assert_includes response.body, "/community/quote-wall</loc>"
    end
    get "/sitemap.xml"

    assert_includes response.body, "/community</loc>"
    assert_no_match(%r{/community/[a-z-]+</loc>}, response.body)
  end

  test "both pages mirror as markdown" do
    with_registry do
      get "/community.md"

      assert_response :success
      assert_equal "text/markdown", response.media_type
      assert_includes response.body, "- [Note card](/community/note-card) (component): A note in a card, with its author and a pin. `bin/rails g poetry:add @poetry/note-card`"
      get "/community/note-card.md"

      assert_response :success
      assert_includes response.body, "`bin/rails g poetry:add @poetry/note-card`"
      assert_includes response.body, "| `body:` | string | required | The note's text. |"
      assert_includes response.body, "| `pinned:` | boolean | `false` | Shows the note pinned. |"
      assert_includes response.body, "| `with_pin` | The glyph a pinned note shows. |"
      assert_includes response.body, "```erb\n<%= community_note_card(body: \"Ship it\", author: \"Ada\") do |note| %>"
      assert_includes response.body, "- Adapted from @acme/note (https://acme.dev/r/note.json), https://github.com/acme/ui. License: MIT. Copyright (c) 2025 Acme"
      get "/community/quote-wall.md"

      assert_includes response.body, "An original community item"
      get "/community/absent.md"

      assert_response :not_found
    end
    get "/community.md"

    assert_includes response.body, "serves no community registry"
  end

  test "an index that does not parse, or an older one that says less, serves what it can" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "registry.json"), "{ not json")
      with_registry(dir) do
        get community_path

        assert_response :success
        assert_select "[data-slot=card]", 0
      end
      File.write(File.join(dir, "registry.json"), JSON.generate({ "items" => [ { "name" => "phone-mockup" } ] }))
      with_registry(dir) do
        get community_item_path("phone-mockup")

        assert_response :success
        assert_select "h1", "Phone mockup"
        assert_select "pre", text: %r{bin/rails g poetry:add @poetry/phone-mockup}
      end
    end
  end
end
