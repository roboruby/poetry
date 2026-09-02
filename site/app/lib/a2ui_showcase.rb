# frozen_string_literal: true

# The A2UI surface demo's scripted agent: two surfaces rendered on the
# server (the spec's basic catalog and Poetry's own catalog), a third
# streamed progressively, and the reply to each user action - all fixed
# messages, so every render is byte-identical and every answer derives
# from the action message alone. No model, no key.
module A2uiShowcase
  BASIC = Poetry::Agent::A2UI::Catalogs::Basic::ID
  NATIVE = Poetry::Agent::A2UI::Catalog::DEFAULT_ID

  # The sign-in surface: the basic catalog with checks the browser enforces.
  SIGN_IN = [
    { "version" => "v1.0",
      "createSurface" => {
        "surfaceId" => "signin", "catalogId" => BASIC, "sendDataModel" => true,
        "dataModel" => { "email" => "", "password" => "", "remember" => true },
        "components" => [
          { "id" => "root", "component" => "Column", "children" => %w[title email password remember submit] },
          { "id" => "title", "component" => "Text", "text" => "## Sign in" },
          { "id" => "email", "component" => "TextField", "label" => "Email", "value" => { "path" => "/email" },
            "placeholder" => "you@example.com",
            "checks" => [
              { "condition" => { "call" => "required", "args" => { "value" => { "path" => "/email" } } },
                "message" => "Email is required" },
              { "condition" => { "call" => "email", "args" => { "value" => { "path" => "/email" } } },
                "message" => "Enter a valid email" }
            ] },
          { "id" => "password", "component" => "TextField", "label" => "Password", "variant" => "obscured",
            "value" => { "path" => "/password" },
            "checks" => [ { "condition" => { "call" => "required", "args" => { "value" => { "path" => "/password" } } } } ] },
          { "id" => "remember", "component" => "CheckBox", "label" => "Remember this device",
            "value" => { "path" => "/remember" } },
          { "id" => "submit", "component" => "Button", "child" => "submit_label", "variant" => "primary",
            "action" => { "event" => { "name" => "sign_in",
                                       "context" => { "email" => { "path" => "/email" },
                                                      "remember" => { "path" => "/remember" } } } },
            "checks" => [
              { "condition" => { "call" => "not",
                                 "args" => { "value" => { "call" => "regex",
                                                          "args" => { "value" => { "path" => "/email" },
                                                                      "pattern" => "@example\\.com$" } } } },
                "message" => "Use your work email, not an example.com address." }
            ] },
          { "id" => "submit_label", "component" => "Text", "text" => "Sign in" }
        ]
      } }
  ].freeze

  # The plan card: Poetry's own catalog, rendered straight from the registry.
  PLAN = [
    { "version" => "v1.0",
      "createSurface" => {
        "surfaceId" => "plan", "catalogId" => NATIVE,
        "dataModel" => { "name" => "Team", "seats" => 5, "price" => "$12 a seat, billed monthly" },
        "components" => [
          { "id" => "root", "component" => "Card", "title" => "title", "description" => "description",
            "footer" => "cta", "children" => %w[badge seats] },
          { "id" => "title", "component" => "Typeset", "text" => { "path" => "/name" } },
          { "id" => "description", "component" => "Typeset", "text" => { "path" => "/price" } },
          { "id" => "badge", "component" => "Badge", "variant" => "secondary", "text" => "most popular" },
          { "id" => "seats", "component" => "Field", "label_text" => "Seats", "children" => [ "seats_input" ] },
          { "id" => "seats_input", "component" => "Input", "type" => "number", "value" => { "path" => "/seats" } },
          { "id" => "cta", "component" => "Button", "variant" => "default", "text" => "Choose plan",
            "action" => { "event" => { "name" => "choose_plan",
                                       "context" => { "seats" => { "path" => "/seats" },
                                                      "plan" => { "path" => "/name" } } } } }
        ]
      } }
  ].freeze

  # The order card, streamed the way an agent streams: the surface, then its
  # components, then the data - each a versioned replace (`_sleep` paces
  # the demo; the tests run instantly). Its text runs through the catalog
  # functions: formatString, formatDate, formatCurrency, pluralize, @index.
  STREAM = [
    { "version" => "v1.0", "createSurface" => { "surfaceId" => "order", "catalogId" => BASIC }, "_sleep" => 400 },
    { "version" => "v1.0",
      "updateComponents" => {
        "surfaceId" => "order",
        "components" => [
          { "id" => "root", "component" => "Card", "child" => "body" },
          { "id" => "body", "component" => "Column", "children" => %w[heading status items] },
          { "id" => "heading", "component" => "Text",
            "text" => { "call" => "formatString",
                        "args" => { "value" => "### Order #${/number}, placed " \
                                               "${formatDate(value: ${/placedAt}, format: 'MMM d, HH:mm')}" } } },
          { "id" => "status", "component" => "Text", "variant" => "caption",
            "text" => { "call" => "formatString",
                        "args" => { "value" => "${/status}: ${/count} " \
                                               "${pluralize(value: ${/count}, one: 'item', other: 'items')}, " \
                                               "${formatCurrency(value: ${/total}, currency: 'USD')}" } } },
          { "id" => "items", "component" => "List", "children" => { "componentId" => "item", "path" => "/items" } },
          { "id" => "item", "component" => "Row", "justify" => "spaceBetween",
            "children" => %w[item_num item_name item_qty] },
          { "id" => "item_num", "component" => "Text", "variant" => "caption",
            "text" => { "call" => "formatString", "args" => { "value" => "${@index(offset: 1)}." } } },
          { "id" => "item_name", "component" => "Text", "text" => { "path" => "name" }, "weight" => 1 },
          { "id" => "item_qty", "component" => "Text", "variant" => "caption",
            "text" => { "call" => "formatString", "args" => { "value" => "x${qty}" } } }
        ]
      }, "_sleep" => 600 },
    { "version" => "v1.0",
      "updateDataModel" => { "surfaceId" => "order",
                             "value" => { "number" => 4821, "placedAt" => "2026-09-01T18:05:00Z",
                                          "status" => "Preparing", "count" => 0, "total" => 0, "items" => [] } },
      "_sleep" => 700 },
    { "version" => "v1.0",
      "updateDataModel" => { "surfaceId" => "order", "path" => "/items",
                             "value" => [ { "name" => "Flat white", "qty" => 2 },
                                          { "name" => "Almond croissant", "qty" => 1 } ] },
      "_sleep" => 300 },
    { "version" => "v1.0",
      "updateDataModel" => { "surfaceId" => "order", "path" => "/count", "value" => 3 }, "_sleep" => 100 },
    { "version" => "v1.0",
      "updateDataModel" => { "surfaceId" => "order", "path" => "/total", "value" => 14.5 }, "_sleep" => 900 },
    { "version" => "v1.0",
      "updateDataModel" => { "surfaceId" => "order", "path" => "/status", "value" => "Out for delivery" },
      "_sleep" => 900 },
    { "version" => "v1.0",
      "updateDataModel" => { "surfaceId" => "order", "path" => "/status", "value" => "Delivered" } }
  ].freeze

  # The session holding the two server-rendered surfaces.
  def self.session
    Poetry::Agent::A2UI::Session.new.tap { |session| session.apply_all(SIGN_IN + PLAN) }
  end

  # The scripted agent's reply to a user action: A2UI messages for the
  # surface the action came from.
  def self.reply(action)
    message = action.to_h["action"]
    context = message["context"]
    case message["name"]
    when "sign_in"
      note = context["remember"] ? "This device is remembered." : "You will sign in again next time."
      [ { "version" => "v1.0",
         "updateComponents" => { "surfaceId" => "signin",
                                 "components" => [
                                   { "id" => "root", "component" => "Column", "children" => %w[welcome note] },
                                   { "id" => "welcome", "component" => "Text",
                                     "text" => "## Welcome back, #{context["email"]}" },
                                   { "id" => "note", "component" => "Text", "variant" => "caption", "text" => note }
                                 ] } } ]
    when "choose_plan"
      seats = context["seats"]
      [ { "version" => "v1.0",
         "updateDataModel" => { "surfaceId" => "plan", "path" => "/name", "value" => "#{context["plan"]}, #{seats} seats" } },
       { "version" => "v1.0",
         "updateComponents" => { "surfaceId" => "plan",
                                 "components" => [ { "id" => "cta", "component" => "Button", "variant" => "secondary",
                                                    "disabled" => true, "text" => "Chosen: #{seats} seats" } ] } } ]
    else
      []
    end
  end
end
