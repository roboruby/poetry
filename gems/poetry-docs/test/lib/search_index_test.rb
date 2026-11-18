require "test_helper"

# The search index feeds the command palette, which takes each address
# once: a second entry with the same address raises on every page the
# palette renders on. The writer refuses such an index, and the committed
# one is held to the same rule so the cause is named here, not by every
# other test at once.
class SearchIndexTest < ActiveSupport::TestCase
  test "an index that holds an address twice is refused, and the address named" do
    entries = [ { "path" => "/components/composer" }, { "path" => "/components/composer#prompts" },
                { "path" => "/components/composer#prompts" } ]

    error = assert_raises(ArgumentError) { Poetry::Docs::SearchIndex.refuse_shared_addresses!(entries) }

    assert_includes error.message, "/components/composer#prompts"
    assert_includes error.message, "rename one"
    assert_nil Poetry::Docs::SearchIndex.refuse_shared_addresses!(entries.uniq)
  end

  test "the committed index holds each address once" do
    shared = Poetry::Docs::SearchIndex.entries.map { |entry| entry["path"] }.tally.select { |_, count| count > 1 }.keys

    assert_empty shared, "two entries share an address - a section id and an example name on one page, most often"
  end
end
