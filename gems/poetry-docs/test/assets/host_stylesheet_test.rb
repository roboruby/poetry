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

  ENGINE = "@layer base{.style-vega .cn-menu svg{width:1rem;height:1rem}.a,.b{color:red}}" \
           "@media (min-width:40rem){.sm\\:p-2{padding:.5rem}}"

  test "a stylesheet's rules are compared one selector at a time, whatever they sit in" do
    sheet = Poetry::Docs::HostStylesheet
    whole = "@layer base{.host{margin:0}.style-vega .cn-menu svg{width:1rem;height:1rem}.a,.b,.host-too{color:red}}" \
            "@media (min-width:40rem){.sm\\:m-1{margin:.25rem}.sm\\:p-2{padding:.5rem}}"

    assert_empty sheet.lost_rules(whole, engine: ENGINE), "a rule joined with the host's own, or moved in its block, is there"
    assert_equal [ [ ".style-vega .cn-menu svg", "width:1rem;height:1rem" ] ],
                 sheet.lost_rules(whole.sub(".style-vega .cn-menu svg{width:1rem;height:1rem}", ""), engine: ENGINE)
    assert_empty sheet.lost_rules("anything", engine: nil)
  end

  test "a build that lacks engine rules is made again, and the good one is kept" do
    engine = Poetry::Docs.root.join("app/assets/builds/poetry_docs.css").read
    builds = [ engine.sub(/\.style-vega [^{}]*\{[^{}]*\}/, ""), engine + ".mt-\\[37px\\]{margin-top:37px}" ]
    calls = 0
    compiler = lambda do |_input, output|
      File.write(output, builds[calls] || builds.last)
      calls += 1
      true
    end

    Dir.mktmpdir do |root|
      path = nil
      _out, err = capture_io do
        path = Poetry::Docs::HostStylesheet.build(root: root, name: "poetry_docs_host", sources: SOURCES, compiler: compiler)
      end

      assert_equal 2, calls
      assert_includes path.read, "margin-top:37px"
      assert_match(/poetry_docs_host\.css was built without 1 of the engine's rules .* building it again/, err)
    end
  end

  test "a build that still lacks them after three is kept, and says so" do
    short = Poetry::Docs.root.join("app/assets/builds/poetry_docs.css").read.sub(/\.style-vega [^{}]*\{[^{}]*\}/, "")
    calls = 0
    compiler = lambda do |_input, output|
      calls += 1
      File.write(output, short)
      true
    end

    Dir.mktmpdir do |root|
      _out, err = capture_io do
        Poetry::Docs::HostStylesheet.build(root: root, name: "poetry_docs_host", sources: SOURCES, compiler: compiler)
      end

      assert_equal 3, calls
      assert_includes err, "kept as it is after 3 builds"
    end
  end

  test "a compiler that fails is an error, as before" do
    Dir.mktmpdir do |root|
      error = assert_raises(Poetry::Docs::HostStylesheet::Error) do
        Poetry::Docs::HostStylesheet.build(root: root, name: "poetry_docs_host", sources: SOURCES,
                                           compiler: ->(_input, _output) { false })
      end

      assert_includes error.message, "the Tailwind build of poetry_docs_host.css failed"
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
