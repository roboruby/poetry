require "test_helper"

# The two fragment caches (highlighted example sources, sidebar item lists)
# run here the way production runs them, with a real memory store and
# controller caching on, so a cached sidebar must still mark the right page
# active and a cached code block must not repeat an id across the page.
class CachedFragmentsTest < ActionDispatch::IntegrationTest
  def with_caching
    store, caching = Rails.cache, ActionController::Base.perform_caching
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActionController::Base.perform_caching = true
    yield
  ensure
    Rails.cache = store
    ActionController::Base.perform_caching = caching
  end

  def active_links
    Nokogiri::HTML5(response.body).css("[data-slot='sidebar-menu-button'][aria-current='page']").map { |n| n["href"] }
  end

  test "the cached sidebar still marks each page's own item active" do
    with_caching do
      get component_path("button")

      assert_equal [ component_path("button") ], active_links

      get component_path("badge")

      assert_equal [ component_path("badge") ], active_links

      get component_path("button")

      assert_equal [ component_path("button") ], active_links, "a cache hit must return the page's own sidebar"
    end
  end

  test "cached code blocks are stable across renders and never duplicate an id" do
    with_caching do
      get component_path("button")
      first = Nokogiri::HTML5(response.body)
      blocks = first.css("[data-component='code_block']").map(&:to_html)

      assert_operator blocks.size, :>=, 5, "the button page carries several example sources"

      get component_path("button")
      second = Nokogiri::HTML5(response.body)

      assert_equal blocks, second.css("[data-component='code_block']").map(&:to_html)
      ids = second.css("[id]").map { |n| n["id"] }
      assert_empty ids.tally.select { |_, count| count > 1 }, "duplicate ids on a cached render"
    end
  end
end
