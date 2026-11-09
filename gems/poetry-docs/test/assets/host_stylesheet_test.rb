# frozen_string_literal: true

require "test_helper"
require "tmpdir"

# Poetry::Docs::HostStylesheet: the engine's stylesheet built again with
# a host's own view folders, so a host page in the docs layout has a rule
# for every class it uses.
class HostStylesheetTest < ActiveSupport::TestCase
  SOURCES = [ Poetry::Docs.root.join("test/fixtures/files/host_views").to_s ].freeze

  test "the entry is the engine's own, then the host's sources from its root" do
    entry = Poetry::Docs::HostStylesheet.entry([ "app/views/community" ], root: "/srv/host")

    assert_equal %(@import "#{Poetry::Docs.root.join("tailwind/application.css")}";\n@source "/srv/host/app/views/community";\n), entry
  end

  test "the build carries the engine's rules and a rule for the host's own class" do
    committed = Poetry::Docs.root.join("app/assets/builds/poetry_docs.css").read

    assert_not_includes committed, "37px", "the fixture's class must be one the engine never uses"
    Dir.mktmpdir do |root|
      path = Poetry::Docs::HostStylesheet.build(root: root, name: "poetry_docs_host", sources: SOURCES)

      assert_equal File.join(File.realpath(root), "app/assets/builds/poetry_docs_host.css"), File.realpath(path)
      built = path.read
      assert_includes built, "margin-top:37px"
      assert_includes built, ".typeset-docs"
      assert_operator built.bytesize, :>=, committed.bytesize
    end
  end

  test "it refuses the engine's own name, and a build with no source" do
    Dir.mktmpdir do |root|
      error = assert_raises(ArgumentError) { Poetry::Docs::HostStylesheet.build(root: root, name: "poetry_docs", sources: SOURCES) }
      assert_match(/its own name/, error.message)
      error = assert_raises(ArgumentError) { Poetry::Docs::HostStylesheet.build(root: root, name: "poetry_docs_host", sources: []) }
      assert_match(/stylesheet_sources/, error.message)
    end
  end

  test "the layouts link the stylesheet the host names, the engine's by default" do
    assert_equal "poetry_docs", Poetry::Docs.config.stylesheet
    assert_empty Poetry::Docs.config.stylesheet_sources
    Poetry::Docs.config.stylesheet = "poetry_docs_host"
    assert_equal "poetry_docs_host", Poetry::Docs.config.stylesheet
  ensure
    Poetry::Docs.config.stylesheet = nil
  end
end
