# frozen_string_literal: true

require "test_helper"

class StreamsTest < Minitest::Test
  A2UI = Poetry::Agent::A2UI

  def setup
    @session = A2UI::Session.new
    @render = lambda { |surface|
      "<div id=\"a2ui-#{surface.id}\" data-version=\"#{surface.version}\">v#{surface.version}</div>"
    }
  end

  def test_first_appearance_appends_into_the_container_then_replaces
    streams = A2UI::Streams.new(session: @session, render: @render, container: "surfaces")
    first = streams.apply({ "createSurface" => { "surfaceId" => "s" } })

    assert_includes first, '<turbo-stream action="append" target="surfaces">'
    assert_includes first, 'data-version="0"'

    second = streams.apply({ "updateDataModel" => { "surfaceId" => "s", "path" => "/a", "value" => 1 } })

    assert_includes second, '<turbo-stream action="vreplace" target="a2ui-s">'
    assert_includes second, 'data-version="1"'
  end

  def test_without_a_container_every_change_replaces
    streams = A2UI::Streams.new(session: @session, render: @render)

    assert_includes streams.apply({ "createSurface" => { "surfaceId" => "s" } }), 'action="vreplace" target="a2ui-s"'
  end

  def test_mark_seen_skips_the_append
    streams = A2UI::Streams.new(session: @session, render: @render, container: "surfaces")
    streams.mark_seen("s")

    assert_includes streams.apply({ "createSurface" => { "surfaceId" => "s" } }), 'action="vreplace"'
  end

  def test_deletion_removes_and_rejections_stream_nothing
    streams = A2UI::Streams.new(session: @session, render: @render)
    streams.apply({ "createSurface" => { "surfaceId" => "s" } })

    assert_equal '<turbo-stream action="remove" target="a2ui-s"></turbo-stream>',
                 streams.apply({ "deleteSurface" => { "surfaceId" => "s" } })
    assert_equal "", streams.apply({ "deleteSurface" => { "surfaceId" => "nope" } })
  end

  def test_apply_all_streams_each_changed_surface_once
    streams = A2UI::Streams.new(session: @session, render: @render, container: "c")
    html = streams.apply_all([{ "createSurface" => { "surfaceId" => "a" } },
                              { "updateDataModel" => { "surfaceId" => "a", "value" => {} } },
                              { "createSurface" => { "surfaceId" => "b" } }])

    assert_equal 2, html.scan("<turbo-stream ").length
    assert_equal 2, html.scan('action="append" target="c"').length
    refute_includes html, "vreplace"
  end
end
