# frozen_string_literal: true

# The API-description surface (S4 of the agent-legibility pass): a minimal
# OpenAPI 3.1 document over the machine endpoints, and the RFC 9727 API
# catalog pointing at it. ENDPOINTS is the one inventory; the suite gates
# every declared path against the real routes so this cannot drift into a
# document that lies. Response schemas stay thin on purpose - the shadcn
# registry item schema remains the authority for item bodies (referenced,
# not restated).
class MachineController < ApplicationController
  ENDPOINTS = {
    "/llms.txt" => { summary: "Site index for agents: every docs page with a one-line description", type: "text/markdown" },
    "/poetry/llms.txt" => { summary: "Component catalog for agents", type: "text/markdown" },
    "/poetry/llms-full.txt" => { summary: "Full component contracts + Stimulus wiring", type: "text/markdown" },
    "/r/registry.json" => { summary: "Registry index (shadcn registry schema)", type: "application/json" },
    "/r/registries.json" => { summary: "Directory of registries", type: "application/json" },
    "/r/{name}" => { summary: "One registry item as <name>.json (shadcn registry-item schema: https://ui.shadcn.com/schema/registry-item.json)", type: "application/json" },
    "/.well-known/skills/index.json" => { summary: "Installable agent skills: names, descriptions, file rosters", type: "application/json" },
    "/.well-known/skills/{skill}/{file}" => { summary: "One skill file as markdown", type: "text/markdown" },
    "/.well-known/api-catalog" => { summary: "RFC 9727 API catalog (this document's address)", type: "application/linkset+json" },
    "/openapi.json" => { summary: "This OpenAPI description", type: "application/json" },
    "/operator-register.json" => { summary: "The operator register: poetry's component contract in GUI-operator vocabulary (system + per-page instructions)", type: "application/json" },
    "/up" => { summary: "Health check", type: "text/html" }
  }.freeze

  def openapi
    render json: {
      openapi: "3.1.0",
      info: {
        title: "poetry docs machine surface",
        summary: "Read-only discovery endpoints: llms indexes, markdown mirrors, the component registry, and installable agent skills. Every HTML docs page additionally mirrors as markdown via a .md suffix or Accept: text/markdown.",
        version: "1.0.0"
      },
      paths: ENDPOINTS.to_h { |path, meta| [ path, path_item(path, meta) ] }
    }
  end

  def operator_register
    render json: OperatorRegister.as_json
  end

  def api_catalog
    render json: {
      linkset: [ {
        anchor: root_url,
        "service-desc": [ { href: "/openapi.json", type: "application/openapi+json" } ],
        "service-doc": [ { href: "/llms.txt", type: "text/markdown" } ]
      } ]
    }, content_type: "application/linkset+json"
  end

  private

  def path_item(path, meta)
    params = path.scan(/\{(\w+)\}/).flatten.map do |name|
      { name: name, in: "path", required: true, schema: { type: "string" } }
    end
    {
      get: {
        summary: meta[:summary],
        parameters: params.presence,
        responses: { "200" => { description: "OK", content: { meta[:type] => {} } } }
      }.compact
    }
  end
end
