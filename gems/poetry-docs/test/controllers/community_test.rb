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

  def with_demos(address)
    Poetry::Docs.config.community_demos = address
    yield
  ensure
    Poetry::Docs.config.community_demos = nil
  end

  test "the index lists every item the registry describes, each linked to its page" do
    with_registry do
      get community_path

      assert_response :success
      assert_select "h1", "Community components"
      assert_select "[data-slot=card]", 3
      assert_select "a[href=?]", "/community/components/note-card", text: "Note card"
      assert_select "a[href=?]", "/community/components/quote-wall", text: "Quote wall"
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
    assert_equal %w[items], bare
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

  test "with a demos address, an item's page lays a frame for its demo over the screenshot" do
    with_registry do
      with_demos("https://demos.example/") do
        get community_item_path("note-card")

        assert_response :success
        assert_select "figure[data-controller='community-demo'][data-community-demo-url-value=?]", "https://demos.example/items/note-card/"
        assert_select "figure[data-action=?]", "turbo:before-morph-element->community-demo#keep"
        assert_select "figure [data-community-demo-target=box] img[data-community-demo-target=shot]", 1
        assert_select "figure [data-community-demo-target=box] iframe[data-community-demo-target=frame][title=?]", "Note card, running" do |frames|
          assert_equal "allow-scripts allow-same-origin allow-forms", frames.first["sandbox"]
          assert_nil frames.first["src"], "the controller loads the demo, so a page that runs no script keeps its screenshot"
          assert_includes frames.first["class"].split, "invisible"
        end
        assert_select "figcaption [data-community-demo-target=still]", /A screenshot of the demo/
        assert_select "figcaption [data-community-demo-target=live][hidden]", /The demo, running.*served from demos\.example, apart from this site/m
      end
    end
  end

  test "another port is another origin, and the address's path is not part of it" do
    with_registry do
      with_demos("http://www.example.com:4120/anywhere") do
        get community_item_path("note-card")

        assert_select "figure[data-community-demo-url-value=?]", "http://www.example.com:4120/items/note-card/"
      end
    end
  end

  test "a page frames nothing at the site's own origin, for an address that is not a web address, or with no screenshot" do
    with_registry do
      get community_item_path("note-card")

      assert_select "iframe", 0
      assert_select "figure[data-controller]", 0
      assert_select "figure img", 1

      [ "http://www.example.com", "http://www.example.com:80/demos", "HTTP://WWW.EXAMPLE.COM", "http://user@www.example.com",
        "javascript:alert(1)", "//demos.example", "demos.example", "ftp://demos.example", "http://", "http://bad host", "  " ].each do |address|
        with_demos(address) do
          get community_item_path("note-card")

          assert_response :success
          assert_select "iframe", 0, "#{address.inspect} must not be framed"
          assert_select "figure img", 1
        end
      end
      with_demos("https://demos.example") do
        get community_item_path("quote-wall")

        assert_response :success
        assert_select "iframe", 0, "the frame stands in the screenshot's box; an item with none has no frame"
      end
    end
  end

  test "an unknown item, and any item on a host with no registry, is a 404" do
    with_registry do
      get "/community/components/absent"

      assert_response :not_found
    end
    get "/community/components/note-card"

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

      assert_includes response.body, "/community/components/note-card</loc>"
      assert_includes response.body, "/community/components/quote-wall</loc>"
    end
    get "/sitemap.xml"

    assert_includes response.body, "/community</loc>"
    assert_no_match(%r{/community/components/[a-z-]+</loc>}, response.body)
  end

  test "both pages mirror as markdown" do
    with_registry do
      get "/community.md"

      assert_response :success
      assert_equal "text/markdown", response.media_type
      assert_includes response.body, "- [Note card](/community/components/note-card) (component): A note in a card, with its author and a pin. `bin/rails g poetry:add @poetry/note-card`"
      get "/community/components/note-card.md"

      assert_response :success
      assert_includes response.body, "`bin/rails g poetry:add @poetry/note-card`"
      assert_includes response.body, "| `body:` | string | required | The note's text. |"
      assert_includes response.body, "| `pinned:` | boolean | `false` | Shows the note pinned. |"
      assert_includes response.body, "| `with_pin` | The glyph a pinned note shows. |"
      assert_includes response.body, "```erb\n<%= community_note_card(body: \"Ship it\", author: \"Ada\") do |note| %>"
      assert_includes response.body, "- Adapted from @acme/note (https://acme.dev/r/note.json), https://github.com/acme/ui. License: MIT. Copyright (c) 2025 Acme"
      assert_no_match(/The demo runs at/, response.body)
      with_demos("https://demos.example") do
        get "/community/components/note-card.md"

        assert_includes response.body, "\n\nThe demo runs at https://demos.example/items/note-card/\n\n"
        get "/community/components/quote-wall.md"

        assert_no_match(/The demo runs at/, response.body)
      end
      get "/community/components/quote-wall.md"

      assert_includes response.body, "An original community item"
      get "/community/components/absent.md"

      assert_response :not_found
    end
    get "/community.md"

    assert_includes response.body, "serves no community registry"
  end

  # A slim index with the item's detail beside it, as the registry builds
  # them now.
  def slim_registry(dir)
    index = { "items" => [
      { "name" => "acme-pricing-table", "type" => "registry:component", "title" => "Pricing table",
        "description" => "Plans side by side.", "registryDependencies" => %w[button card], "dependencies" => [],
        "meta" => { "community" => true, "version" => "1.3.0", "javascript" => "stimulus", "traits" => %w[animated device-frame],
                    "source" => { "registry" => "@acme", "item" => "pricing-table", "license" => "MIT" } } },
      { "name" => "acme-card", "type" => "registry:style", "title" => "Acme cards", "description" => "A restyle.",
        "registryDependencies" => %w[card], "meta" => { "community" => true, "javascript" => "none", "restyles" => "card" } }
    ] }
    about = { "name" => "acme-pricing-table", "files" => [ { "target" => "app/components/community/acme_pricing_table/component.rb" } ],
              "docs" => "Pass plans: as an array.",
              "meta" => { "demo" => "<%= acme_pricing_table(plans: @plans) %>",
                          "source" => { "registry" => "@acme", "item" => "pricing-table", "license" => "MIT",
                                        "repository" => "https://github.com/acme/ui", "copyright" => "Copyright (c) 2026 Acme" },
                          "component" => { "helper" => "acme_pricing_table",
                                           "options" => [ { "name" => "plans", "type" => "array", "required" => true } ] } } }
    File.write(File.join(dir, "registry.json"), JSON.generate(index))
    FileUtils.mkdir_p(File.join(dir, "about"))
    File.write(File.join(dir, "about/acme-pricing-table.json"), JSON.generate(about))
  end

  test "an item's page lays its detail over the slim index, and says what it brings and how it looks" do
    Dir.mktmpdir do |dir|
      slim_registry(dir)
      with_registry(dir) do
        get community_item_path("acme-pricing-table")

        assert_response :success
        assert_select "h1", "Pricing table"
        assert_select "pre", text: /acme_pricing_table\(plans: @plans\)/
        assert_select "code", "acme_pricing_table"
        assert_select "section:has(#install) li", "app/components/community/acme_pricing_table/component.rb"
        assert_includes response.body, "Copyright (c) 2026 Acme"
        assert_select "[data-fact=javascript]", "Brings a Stimulus controller."
        assert_select "[data-fact=traits] [data-slot=badge]", 2
        assert_select "[data-fact=traits]", text: /device frame/
        assert_select "[data-fact=restyles]", 0
        get "/community/components/acme-pricing-table.md"

        assert_includes response.body, "Brings a Stimulus controller."
        assert_includes response.body, "Looks: animated, device frame."
      end
    end
  end

  test "a restyle's page names the Poetry component it restyles, and an item with no detail shows what the index says" do
    Dir.mktmpdir do |dir|
      slim_registry(dir)
      with_registry(dir) do
        get community_item_path("acme-card")

        assert_response :success
        assert_select "h1", "Acme cards"
        assert_select "[data-fact=restyles] a[href='/components/card']", "card"
        assert_select "[data-fact=javascript]", "Brings no JavaScript of its own."
        get community_path

        assert_select "a[href=?]", "/community/components/acme-pricing-table", text: "Pricing table"
      end
      File.write(File.join(dir, "about/acme-pricing-table.json"), "{ not json")
      with_registry(dir) do
        get community_item_path("acme-pricing-table")

        assert_response :success
        assert_select "h1", "Pricing table"
      end
    end
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
