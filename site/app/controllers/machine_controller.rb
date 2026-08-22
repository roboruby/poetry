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
    "/.well-known/agent-skills/index.json" => { summary: "Agent-skills discovery index (schemas.agentskills.io/discovery/0.2.0): name, description, type, payload url, sha256 digest per skill - what `npx skills add` reads", type: "application/json" },
    "/.well-known/agent-skills/{archive}" => { summary: "One skill payload as a flat <name>.tar.gz, the digest target", type: "application/gzip" },
    "/.well-known/api-catalog" => { summary: "RFC 9727 API catalog (this document's address)", type: "application/linkset+json" },
    "/openapi.json" => { summary: "This OpenAPI description", type: "application/json" },
    "/operator-register.json" => { summary: "The operator register: poetry's component contract in GUI-operator vocabulary (system + per-page instructions)", type: "application/json" },
    "/sitemap.xml" => { summary: "Sitemap of every docs page (DocsCatalog-generated)", type: "application/xml" },
    "/robots.txt" => { summary: "Crawler welcome + Content-Signal + sitemap pointer", type: "text/plain" },
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

  # Absolute URLs derive from the request host - the site has no fixed
  # domain under the naming hold, so nothing is hardcoded.
  def sitemap
    urls = ([ "/" ] + DocsCatalog.all.map(&:path)).map do |path|
      "  <url><loc>#{request.base_url}#{path}</loc></url>"
    end
    xml = [ %(<?xml version="1.0" encoding="UTF-8"?>),
            %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">),
            *urls, "</urlset>", "" ].join("\n")
    render plain: xml, content_type: "application/xml"
  end

  def robots
    render plain: <<~TXT, content_type: "text/plain"
      # Crawlers are welcome - this site exists to be read by humans and agents
      # alike. Content-Signal (contentsignals.org) states what fetched bytes may
      # be used for; the agent-facing index is /llms.txt and every page mirrors
      # as markdown at <url>.md.
      User-agent: *
      Content-Signal: search=yes, ai-input=yes, ai-train=yes
      Allow: /

      Sitemap: #{request.base_url}/sitemap.xml
    TXT
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
