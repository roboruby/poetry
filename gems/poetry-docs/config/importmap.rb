# frozen_string_literal: true

# The docs engine's pins, joined to the host's importmap by the engine.
# The host pins @hotwired/turbo-rails, @hotwired/stimulus and
# @hotwired/stimulus-loading; the poetry gems pin their own packages.
pin "poetry_docs/application", to: "poetry_docs/application.js"
pin_all_from Poetry::Docs::Engine.root.join("app/javascript/poetry_docs/controllers"),
             under: "poetry_docs/controllers", to: "poetry_docs/controllers"
