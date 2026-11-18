require "test_helper"

# What keeps a docs page from scrolling sideways on a phone. A sweep of
# all 206 pages at 390px found 25 that did, for three reasons, and these
# hold each reason shut: a table with nothing to scroll it, a demo wider
# than its preview box, and a long unbroken string.
class PhoneLayoutTest < ActionDispatch::IntegrationTest
  test "every table on a docs page sits in a box that scrolls it" do
    pages = Poetry::Docs.root.glob("app/views/poetry/docs/docs/**/*.html.erb")
    bare = pages.select do |page|
      text = page.read
      text.scan("<table").size > text.scan("overflow-x-auto").size
    end

    assert_empty bare.map { |page| page.relative_path_from(Poetry::Docs.root).to_s },
                 "wrap the table: <div class=\"overflow-x-auto\"><table class=\"min-w-[36rem]\">"
  end

  test "a preview box scrolls a demo wider than itself, from its start edge" do
    get "/components/tabs"

    assert_response :success
    frames = css_select("main [role=tabpanel] > div.overflow-x-auto")

    assert_operator frames.size, :>=, 1
    assert(frames.all? { |frame| frame["class"].include?("items-center-safe") }, "centred only while the demo fits")
  end

  test "long unbroken strings in prose and reference wrap, and code blocks are left to scroll" do
    css = Poetry::Docs.root.join("tailwind/application.css").read

    assert_includes css, %(main :where(code, .font-mono):not(pre *, [data-slot="code-block"] *) {\n  overflow-wrap: anywhere;)
    assert_includes Poetry::Docs.root.join("app/assets/builds/poetry_docs.css").read, "overflow-wrap:anywhere"
  end
end
