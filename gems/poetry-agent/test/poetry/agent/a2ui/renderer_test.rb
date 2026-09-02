# frozen_string_literal: true

require "test_helper"
require "rendering_helper"
require "json"

# Renders through the dummy Rails host (poetry-ui's real components).
class RendererTest < Minitest::Test
  A2UI = Poetry::Agent::A2UI
  FIXTURES = File.expand_path("../../../fixtures/a2ui", __dir__)

  def fixture(name)
    JSON.parse(File.read(File.join(FIXTURES, "#{name}.json")))["messages"]
  end

  def session_for(messages)
    A2UI::Session.new.tap { |session| session.apply_all(messages) }
  end

  def render(surface, **)
    renderer = A2UI::Renderer.new(surface, view: view_context, **)
    [renderer.call.to_s, renderer]
  end

  def basic_surface(components, data: {}, send_data_model: false)
    session = A2UI::Session.new
    session.apply({ "createSurface" => { "surfaceId" => "s", "catalogId" => A2UI::Catalogs::Basic::ID,
                                         "sendDataModel" => send_data_model, "dataModel" => data,
                                         "components" => components } })

    assert_empty session.errors
    session.surface("s")
  end

  def test_every_official_example_renders_without_warnings
    Dir[File.join(FIXTURES, "*.json")].each do |path|
      session = session_for(JSON.parse(File.read(path))["messages"])

      assert_empty session.errors, path
      session.surfaces.each_value do |surface|
        html, renderer = render(surface, action_url: "/a2ui")

        assert_empty renderer.warnings, "#{File.basename(path)}: #{renderer.warnings.inspect}"
        assert_includes html, "id=\"a2ui-#{surface.id}\""
        assert_includes html, "data-version=\"#{surface.version}\""
      end
    end
  end

  def test_functions_format_the_product_card_and_the_track_list
    html, = render(session_for(fixture("05_product-card")).surface("gallery-product-card"))

    assert_includes html, "$199.99"
    assert_includes html, "(2,847 reviews)"

    html, = render(session_for(fixture("18_track-list")).surface("gallery-track-list"))

    assert_includes html, "<p>1</p>"
    assert_includes html, "<p>3</p>"
  end

  def test_check_failures_render_under_their_controls
    surface = basic_surface(
      [{ "id" => "root", "component" => "Column", "children" => %w[email agree go] },
       { "id" => "email", "component" => "TextField", "label" => "Email", "value" => { "path" => "/email" } },
       { "id" => "agree", "component" => "CheckBox", "label" => "Agree", "value" => { "path" => "/agree" } },
       { "id" => "go", "component" => "Button", "child" => "gl", "action" => { "event" => { "name" => "go" } } },
       { "id" => "gl", "component" => "Text", "text" => "Go" }],
      data: { "email" => "nope", "agree" => false }
    )
    errors = { "email" => [{ message: "Invalid email format" }], "agree" => [{ message: "Required" }],
               "go" => [{ message: "Fix the form first" }] }
    html, renderer = render(surface, action_url: "/a2ui", errors: errors)

    assert_empty renderer.warnings
    assert_match(%r{<input[^>]* name="a2ui\[values\]\[/email\]"[^>]* aria-invalid="true"}, html)
    assert_includes html, "Invalid email format"
    assert_match(%r{<p class="text-sm text-destructive" role="alert">Required</p>}, html)
    assert_match(%r{<p class="text-sm text-destructive" role="alert">Fix the form first</p>}, html)
    assert_equal "Fix the form first", renderer.error_for(surface.component("go"))
    assert_nil renderer.error_for(surface.component("gl"))
  end

  def test_the_login_form_is_a_form_of_named_inputs_and_a_submit_button
    surface = session_for(fixture("00_simple-login-form")).surface("gallery-simple-login-form")
    html, renderer = render(surface, action_url: "/a2ui/action")

    assert_empty renderer.warnings
    assert_match(%r{<form[^>]* id="a2ui-gallery-simple-login-form"[^>]* action="/a2ui/action"[^>]* method="post"}, html)
    assert_includes html, 'name="a2ui[surface]" value="gallery-simple-login-form"'
    assert_includes html, "<h2>Login</h2>"
    assert_match(%r{<label[^>]* for="a2ui-gallery-simple-login-form-username_field">Username</label>}, html)
    assert_match(%r{<input[^>]* type="text"[^>]* name="a2ui\[values\]\[/username\]"}, html)
    assert_match(%r{<input[^>]* type="password"[^>]* name="a2ui\[values\]\[/password\]"}, html)
    assert_match(%r{<button[^>]* name="a2ui\[action\]"[^>]* value="submit_button"[^>]*>.*?Sign In.*?</button>}m, html)
    assert_match(/<button[^>]* type="submit"/, html)
  end

  def test_without_an_action_url_the_surface_is_a_container_and_buttons_are_inert
    surface = session_for(fixture("00_simple-login-form")).surface("gallery-simple-login-form")
    html, = render(surface)

    assert_match(
      /\A<div id="a2ui-gallery-simple-login-form" data-a2ui-surface="gallery-simple-login-form" data-version="1">/, html
    )
    refute_includes html, "<form"
    assert_match(/<button[^>]* type="button"/, html)
    refute_includes html, "a2ui[action]"
  end

  def test_input_components_bind_by_pointer_and_carry_their_checks
    surface = basic_surface(
      [{ "id" => "root", "component" => "Column", "children" => %w[name email bio news size toppings volume when] },
       { "id" => "name", "component" => "TextField", "label" => "Name", "value" => { "path" => "/name" },
         "checks" => [{ "condition" => { "call" => "required", "args" => { "value" => { "path" => "/name" } } } },
                      { "condition" => { "call" => "length",
                                         "args" => { "value" => { "path" => "/name" }, "min" => 2, "max" => 40 } } }] },
       { "id" => "email", "component" => "TextField", "label" => "Email", "value" => { "path" => "/email" },
         "placeholder" => "you@example.com",
         "checks" => [{ "condition" => { "call" => "email", "args" => { "value" => { "path" => "/email" } } } },
                      { "condition" => { "call" => "regex",
                                         "args" => { "value" => { "path" => "/email" }, "pattern" => ".+@.+" } } }] },
       { "id" => "bio", "component" => "TextField", "label" => "Bio", "variant" => "longText",
         "value" => { "path" => "/bio" } },
       { "id" => "news", "component" => "CheckBox", "label" => "Newsletter", "value" => { "path" => "/news" } },
       { "id" => "size", "component" => "ChoicePicker", "label" => "Size", "value" => { "path" => "/size" },
         "options" => [{ "label" => "Small", "value" => "s" }, { "label" => "Medium", "value" => "m" }] },
       { "id" => "toppings", "component" => "ChoicePicker", "label" => "Toppings", "variant" => "multipleSelection",
         "value" => { "path" => "/toppings" },
         "options" => [{ "label" => "Nuts", "value" => "nuts" }, { "label" => "Cream", "value" => "cream" }] },
       { "id" => "volume", "component" => "Slider", "label" => "Volume", "min" => 0, "max" => 100, "steps" => 10,
         "value" => { "path" => "/volume" } },
       { "id" => "when", "component" => "DateTimeInput", "enableDate" => true, "value" => { "path" => "/when" },
         "min" => "2026-01-01" }],
      data: { "name" => "Ada", "email" => "", "bio" => "hi", "news" => true, "size" => ["m"], "toppings" => ["nuts"],
              "volume" => 40, "when" => "2026-09-02" }
    )
    html, renderer = render(surface, action_url: "/a2ui")

    assert_empty renderer.warnings
    assert_match(Regexp.new('<input id="a2ui-s-name" required="required" minlength="2" maxlength="40"[^>]* ' \
                            'type="text"[^>]* name="a2ui\\[values\\]\\[/name\\]" value="Ada"'), html)
    assert_match(Regexp.new('<input[^>]* pattern=".\\+@.\\+"[^>]* type="email"[^>]* ' \
                            'name="a2ui\\[values\\]\\[/email\\]"[^>]* placeholder="you@example.com"'), html)
    assert_match(%r{<textarea[^>]* name="a2ui\[values\]\[/bio\]"[^>]*>\s*hi</textarea>}, html)
    assert_match(%r{<input type="hidden" name="a2ui\[values\]\[/news\]" value="false"}, html)
    assert_match(%r{<input type="checkbox"[^>]* name="a2ui\[values\]\[/news\]" value="true" checked}, html)
    assert_includes html, 'role="radiogroup"'
    assert_match(%r{type="radio"[^>]* name="a2ui\[values\]\[/size\]"[^>]* value="m"[^>]* checked}, html)
    assert_match(%r{<input type="hidden" name="a2ui\[values\]\[/toppings\]\[\]" value=""}, html)
    assert_match(%r{type="checkbox"[^>]* name="a2ui\[values\]\[/toppings\]\[\]" value="nuts" checked}, html)
    assert_match(%r{type="checkbox"[^>]* name="a2ui\[values\]\[/toppings\]\[\]" value="cream"(?! checked)}, html)
    assert_match(/data-poetry--core--slider-step-value="10"/, html)
    assert_match(%r{name="a2ui\[values\]\[/volume\]"[^>]* value="40"}, html)
    assert_match(
      %r{<input[^>]* min="2026-01-01"[^>]* type="date"[^>]* name="a2ui\[values\]\[/when\]" value="2026-09-02"}, html
    )
  end

  def test_tabs_modal_divider_list_media_and_weights
    surface = basic_surface(
      [{ "id" => "root", "component" => "Column", "children" => %w[tabs modal div list img video audio icon row] },
       { "id" => "tabs", "component" => "Tabs",
         "tabs" => [{ "title" => "One", "child" => "t1" }, { "title" => "Two", "child" => "t2" }] },
       { "id" => "t1", "component" => "Text", "text" => "first", "variant" => "caption" },
       { "id" => "t2", "component" => "Text", "text" => "second" },
       { "id" => "modal", "component" => "Modal", "trigger" => "mt", "content" => "mc" },
       { "id" => "mt", "component" => "Button", "child" => "mtl", "variant" => "borderless" },
       { "id" => "mtl", "component" => "Text", "text" => "Open **details**" },
       { "id" => "mc", "component" => "Text", "text" => "Inside" },
       { "id" => "div", "component" => "Divider", "axis" => "vertical" },
       { "id" => "list", "component" => "List", "direction" => "horizontal", "children" => ["t2"] },
       { "id" => "img", "component" => "Image", "url" => "https://example.com/a.png", "fit" => "cover",
         "variant" => "avatar",
         "description" => "Ada" },
       { "id" => "video", "component" => "Video", "url" => "https://example.com/a.mp4",
         "posterUrl" => "https://example.com/p.png" },
       { "id" => "audio", "component" => "AudioPlayer", "url" => "https://example.com/a.mp3",
         "description" => "Track" },
       { "id" => "icon", "component" => "Icon", "name" => "play" },
       { "id" => "row", "component" => "Row", "justify" => "spaceBetween", "align" => "center", "children" => %w[w1 w2],
         "accessibility" => { "label" => "Totals" } },
       { "id" => "w1", "component" => "Text", "text" => "left", "weight" => 2 },
       { "id" => "w2", "component" => "Text", "text" => "right" }]
    )
    html, renderer = render(surface)

    assert_empty renderer.warnings
    assert_includes html, 'role="tablist"'
    assert_match(%r{<button[^>]* role="tab"[^>]*>One</button>}, html)
    assert_includes html, 'data-controller="poetry--core--dialog"'
    assert_match(%r{<button[^>]* data-action="poetry--core--dialog#open"[^>]*>.*?Open details.*?</button>}m, html)
    assert_includes html, "Inside"
    assert_match(/data-slot="separator" data-orientation="vertical"/, html)
    assert_includes html, "flex-row overflow-x-auto"
    assert_match(
      %r{<img src="https://example.com/a.png" alt="Ada" class="rounded-md object-cover size-10 rounded-full"}, html
    )
    assert_match(%r{<video controls="controls" src="https://example.com/a.mp4" poster="https://example.com/p.png"},
                 html)
    assert_match(%r{<audio controls="controls" src="https://example.com/a.mp3" aria-label="Track"}, html)
    assert_includes html, 'data-slot="icon"'
    assert_match(Regexp.new('<div class="flex flex-row gap-4 justify-between items-center" aria-label="Totals">' \
                            '<div style="flex: 2 1 0%">'), html)
    assert_includes html, 'class="text-sm text-muted-foreground"><p>first</p></div>'
  end

  def test_buttons_link_for_open_url_and_warn_for_other_local_actions
    surface = basic_surface(
      [{ "id" => "root", "component" => "Column", "children" => %w[link other] },
       { "id" => "link", "component" => "Button", "child" => "l1", "variant" => "primary",
         "action" => { "functionCall" => { "call" => "openUrl", "args" => { "url" => "https://example.com/docs" } } } },
       { "id" => "l1", "component" => "Text", "text" => "Docs" },
       { "id" => "other", "component" => "Button", "child" => "l2",
         "action" => { "functionCall" => { "call" => "openUrl", "args" => { "url" => "javascript:alert(1)" } } } },
       { "id" => "l2", "component" => "Text", "text" => "Nope" }]
    )
    html, renderer = render(surface, action_url: "/a2ui")

    assert_match(%r{<a[^>]* href="https://example.com/docs"[^>]*>.*?Docs.*?</a>}m, html)
    assert_match(%r{<button[^>]* disabled[^>]*>.*?Nope.*?</button>}m, html)
    assert_equal ['function "openUrl": openUrl: only http and https URLs open'], renderer.warnings
  end

  def test_unknown_components_and_dangling_references_warn_and_render_nothing
    surface = basic_surface([{ "id" => "root", "component" => "Column", "children" => %w[ghost mystery text] },
                             { "id" => "mystery", "component" => "Hologram" },
                             { "id" => "text", "component" => "Text", "text" => "still here" }])
    html, renderer = render(surface)

    assert_includes html, "still here"
    assert_equal ['unknown component id "ghost"', 'unknown basic catalog component "Hologram"'], renderer.warnings
  end

  def test_library_refusals_become_warnings
    surface = basic_surface([{ "id" => "root", "component" => "Column", "children" => %w[icon text] },
                             { "id" => "icon", "component" => "Icon", "name" => "no-such-icon" },
                             { "id" => "text", "component" => "Text", "text" => "ok" }])
    html, renderer = render(surface)

    assert_includes html, "ok"
    assert_equal 1, renderer.warnings.length
    assert_match(/\AIcon "icon": /, renderer.warnings.first)
  end

  def test_templates_render_once_per_item_with_relative_bindings
    surface = session_for(fixture("18_track-list")).surface("gallery-track-list")
    html, = render(surface)

    assert_includes html, "Weightless"
    assert_equal surface.data["tracks"].length, html.scan('alt=""').length
  end

  def test_the_native_catalog_renders_registry_components_slots_and_bound_inputs
    session = A2UI::Session.new
    session.apply({ "createSurface" => {
                    "surfaceId" => "plan", "catalogId" => A2UI::Catalog::DEFAULT_ID,
                    "dataModel" => { "plan" => "Team", "seats" => 5 },
                    "components" => [
                      { "id" => "root", "component" => "Card", "title" => "ttl", "description" => "dsc",
                        "children" => %w[badge seats tabs cta] },
                      { "id" => "ttl", "component" => "Typeset", "text" => { "path" => "/plan" } },
                      { "id" => "dsc", "component" => "Typeset", "text" => "Billed <monthly>" },
                      { "id" => "badge", "component" => "Badge", "variant" => "secondary", "text" => "popular" },
                      { "id" => "seats", "component" => "Input", "type" => "number",
                        "value" => { "path" => "/seats" } },
                      { "id" => "tabs", "component" => "Tabs", "label" => "Details", "tabs" => %w[tab1 tab2] },
                      { "id" => "tab1", "component" => "Typeset", "text" => "Overview", "children" => ["o"] },
                      { "id" => "o", "component" => "Typeset", "text" => "Everything included." },
                      { "id" => "tab2", "component" => "Typeset", "text" => "Limits" },
                      { "id" => "cta", "component" => "Button", "variant" => "default", "text" => "Choose plan",
                        "accessibility" => { "label" => "Choose the Team plan" },
                        "action" => { "event" => { "name" => "choose",
                                                   "context" => { "seats" => { "path" => "/seats" } } } } }
                    ]
                  } })

    assert_empty session.errors

    surface = session.surface("plan")
    html, renderer = render(surface, action_url: "/a2ui")

    assert_empty renderer.warnings
    assert_match(%r{<h3 data-slot="card-title"[^>]*><div class="typeset"[^>]*>Team</div></h3>}, html)
    assert_includes html, "Billed &lt;monthly&gt;"
    assert_match(/data-slot="badge" data-variant="secondary"[^>]*>popular</, html)
    assert_match(%r{<input[^>]* type="number"[^>]* name="a2ui\[values\]\[/seats\]" value="5"}, html)
    assert_match(%r{<button[^>]* role="tab"[^>]*>Overview</button>}, html)
    assert_includes html, "Everything included."
    assert_match(%r{<button[^>]* aria-label="Choose the Team plan"[^>]*>.*?Choose plan.*?</button>}m, html)
    assert_match(/name="a2ui\[action\]" value="cta"/, html)
    assert_equal [{ path: "/seats", kind: :string }], surface.inputs

    action = session.action(surface_id: "plan", source: "cta", values: { "/seats" => "12" })

    assert_equal({ "seats" => "12" }, action.to_h.dig("action", "context"))
  end

  def test_the_native_catalog_warns_on_unknown_components
    session = A2UI::Session.new
    session.apply({ "createSurface" => { "surfaceId" => "n", "catalogId" => A2UI::Catalog::DEFAULT_ID,
                                         "components" => [{ "id" => "root", "component" => "Bogus" }] } })
    _html, renderer = render(session.surface("n"))

    assert_equal ['unknown component "Bogus"'], renderer.warnings
  end

  def test_an_empty_surface_renders_its_wrapper
    session = A2UI::Session.new
    session.apply({ "createSurface" => { "surfaceId" => "e" } })
    html, renderer = render(session.surface("e"), html: { class: "mt-4" })

    assert_equal '<div id="a2ui-e" data-a2ui-surface="e" data-version="0" class="mt-4"></div>', html
    assert_empty renderer.warnings
  end
end
