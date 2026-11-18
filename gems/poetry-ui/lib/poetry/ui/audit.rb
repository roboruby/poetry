# frozen_string_literal: true

require "json"
require "time"

module Poetry
  module Ui
    # The consumer-app audit, `bin/rails poetry:audit`: what the app's
    # templates exercise of the catalog, what they paint outside it, what
    # the check and the design tier find, which partials nothing renders,
    # and where the routes, pages and links lead. Four JSON files under
    # `.poetry/audit/` an agent cites by field, one self-contained HTML
    # report composed from Poetry's own components, and a summary on the
    # terminal. Every number is counted from parsed source and the booted
    # route set; a value a template passes dynamically is listed as
    # dynamic, an edge whose target is not literal is recorded by kind.
    #
    # @example
    #   audit = Poetry::Ui::Audit.new(root: Rails.root, catalog: Poetry::Ui::CheckCatalog.build(root: Rails.root),
    #                                 routes: Poetry::Ui::Audit.routes_from(Rails.application.routes))
    #   audit.run
    #   audit.write
    class Audit
      # The files' schema version; a reader pins it.
      SCHEMA = 1
      # Where the files land, under the app root.
      OUTPUT = ".poetry/audit"
      # The templates the inventory, the token readers and the design tier read.
      TEMPLATE_GLOB = "app/{views,components}/**/*.html.erb"
      # The Ruby the check's declaration tiers read.
      RUBY_GLOB = "app/**/*.rb"
      # The files the flow edges are read from.
      EDGE_GLOB = "app/{views,components,helpers,controllers}/**/*.{erb,rb}"
      # The edge kinds a booted route set resolves.
      RESOLVABLE_KINDS = %w[path_helper literal_path].freeze
      # The calls that submit, so a literal path resolves to the POST route first.
      SUBMITTING_CALLS = %w[form_with form_for button_to].freeze

      # The routes of a Rails route set as plain data: every route with a
      # controller and an action (mounts and redirects have none), the
      # framework's own left out.
      #
      # @param route_set [ActionDispatch::Routing::RouteSet]
      # @return [Array<Hash>] "name", "verb", "path", "controller" and "action" per route
      def self.routes_from(route_set)
        route_set.routes.filter_map do |route|
          controller = route.defaults[:controller]
          action = route.defaults[:action]
          next unless controller && action
          next if controller.start_with?("rails/", "action_mailbox/", "active_storage/")

          { "name" => route.name, "verb" => route.verb.to_s, "path" => route.path.spec.to_s.delete_suffix("(.:format)"),
            "controller" => controller, "action" => action }
        end
      end

      # The audit's data once run (nil before).
      attr_reader :data

      # An audit over one app, run once and written once.
      #
      # @param root [Pathname, String] the app root
      # @param catalog [Poetry::Core::Check::Catalog] the host's check catalog (CheckCatalog.build)
      # @param routes [Array<Hash>] the routes (routes_from), or none outside a booted app
      # @param compiled_css [Pathname, String, nil] the compiled stylesheet the report inlines
      # @param app [String, nil] the app's name for the report's header
      # @param renderer [#render, nil] what renders the report (the app's ApplicationController by default)
      def initialize(root:, catalog:, routes: [], compiled_css: nil, app: nil, renderer: nil)
        @root = Pathname.new(root)
        @catalog = catalog
        @routes = routes
        @compiled_css = compiled_css && Pathname.new(compiled_css)
        @app = app || @root.basename.to_s
        @renderer = renderer
      end

      # Runs every analyzer and assembles the data.
      #
      # @return [Hash] the data, "summary" first
      def run
        templates = paths(TEMPLATE_GLOB)
        findings, calls = check(templates + paths(RUBY_GLOB))
        design = design_findings(templates)
        inventory = Poetry::Core::Audit::Inventory.build(calls: calls, catalog: @catalog)
        tokens = Poetry::Core::Audit::Tokens.aggregate(templates.to_h { |path| [relative(path), token_scan(path)] })
        health = Poetry::Core::Audit::Health.summarize(findings)
        health["design"] = Poetry::Core::Audit::Health.summarize(design).slice("warnings", "by_rule", "findings")
        partials = partials_report
        flows = flows_report(calls, partials)
        @data = {
          "summary" => summary(templates: templates, inventory: inventory, tokens: tokens, health: health,
                               partials: partials, flows: flows),
          "inventory" => { "schema" => SCHEMA }.merge(inventory).merge(tokens),
          "health" => { "schema" => SCHEMA }.merge(health),
          "flows" => { "schema" => SCHEMA }.merge(flows).merge("partials" => partials)
        }
      end

      # Writes the four JSON files and the report, each file whole (written
      # beside, then moved into place).
      #
      # @param dir [Pathname, String] the output folder (`.poetry/audit` under the root by default)
      # @return [Array<Pathname>] the files written
      def write(dir = @root.join(OUTPUT))
        run unless @data
        dir = Pathname.new(dir)
        dir.mkpath
        files = @data.map do |name, payload|
          atomic_write(dir.join("#{name}.json"), JSON.pretty_generate(payload) << "\n")
        end
        files << atomic_write(dir.join("report.html"), report_html)
      end

      # The terminal summary.
      #
      # @return [String]
      def summary_text
        run unless @data
        s = @data["summary"]
        lines = ["poetry:audit: #{s["app"]} - #{s["templates"]} templates, #{s["ruby_files"]} Ruby files"]
        components = s["components"]
        lines << "  components  #{components["used"]} helpers across #{components["call_sites"]} call sites; " \
                 "axis coverage #{s["coverage"]["used"]} of #{s["coverage"]["declared"]} declared values " \
                 "(#{s["coverage"]["percent"]}%)"
        lines << "  health      #{s["health"]["errors"]} check errors, #{s["health"]["warnings"]} warnings, " \
                 "#{s["health"]["design_warnings"]} design warnings"
        lines << "  paint       #{s["raw_colors"]["unique"]} raw colors (#{s["raw_colors"]["uses"]} uses), " \
                 "#{s["off_scale"]["unique"]} off-scale lengths (#{s["off_scale"]["uses"]} uses), " \
                 "#{s["font_sizes"]["distinct"]} font sizes app-wide" \
                 "#{" (most in one template: #{s["font_sizes"]["max_per_template"]})" if s["font_sizes"]["template"]}"
        lines << "  icons       #{s["icons"]["distinct"]} names across #{s["icons"]["uses"]} uses"
        p = s["partials"]
        partials = "not analyzed (#{p["reason"]})"
        if p["available"]
          partials = "#{p["unused"]} with no static render site, #{p["unresolved"]} renders naming no file, " \
                     "#{p["dynamic"]} dynamic renders"
        end
        lines << "  partials    #{partials}"
        f = s["flows"]
        lines << "  flows       #{f["routes"]} routes, #{f["pages"]} with a template; #{f["edges"]} edges, " \
                 "#{f["resolved"]} resolved to a route, #{f["unresolved"]} recorded by kind"
        lines.join("\n")
      end

      private

      # The files under the root matching a glob, in glob order.
      def paths(glob) = Dir.glob(@root.join(glob).to_s)

      # A path inside the root.
      def relative(path) = path.to_s.delete_prefix("#{@root}/")

      # The check over the files, its findings and the helper calls it saw
      # (both stamped with paths inside the root).
      def check(files)
        calls = []
        runner = Poetry::Core::Check::Runner.new(@catalog)
        findings = runner.run(files, root: @root, calls: calls)
        findings.each { |finding| finding.file = relative(finding.file) }
        calls.each { |call| call.file = relative(call.file) }
        [findings, calls]
      end

      # The design tier over the page templates (mail has no tokens).
      def design_findings(templates)
        templates.reject { |path| Poetry::Core::Check.mail_template?(path, root: @root) }.flat_map do |path|
          Poetry::Core::DesignLint.lint(File.read(path, encoding: "UTF-8"), file: relative(path))
        end
      end

      # One template's token counts.
      def token_scan(path)
        Poetry::Core::Audit::Tokens.scan(File.read(path, encoding: "UTF-8"), catalog: @catalog)
      end

      # Herb's render graph over the app: partials nothing renders, static
      # renders naming no file, dynamic renders, and the graph itself for
      # the pages. Absent when the analyzer is not installed.
      def partials_report
        require "herb/analysis/render_analyzer"
        result = render_analysis(Herb::Analysis::RenderAnalyzer.new(@root.to_s))
        graph = Hash.new { |hash, key| hash[key] = [] }
        result.render_calls.each do |call|
          next unless call[:partial] && !call[:dynamic]

          target = result.partial_files[call[:partial]]
          graph[relative(call[:file])] << relative(target) if target
        end
        {
          "available" => true,
          "unused" => result.unused.map { |name, file| { "partial" => name, "file" => relative(file) } }
                            .sort_by { |row| row["file"] },
          "unresolved" => result.unresolved.map { |call| render_call(call) },
          "dynamic" => result.dynamic_calls.map { |call| render_call(call) },
          "graph" => graph
        }
      rescue LoadError, StandardError => e
        { "available" => false, "reason" => "#{e.class}: #{e.message}", "unused" => [], "unresolved" => [],
          "dynamic" => [], "graph" => {} }
      end

      # The analyzer's result. Its own file walk forks through the
      # `parallel` gem, which a host need not carry, so the templates are
      # read one by one here and handed to its collected-input entry; a
      # Herb without that seam runs its own walk.
      def render_analysis(analyzer)
        return analyzer.analyze unless analyzer.respond_to?(:process_file_for_render_calls, true)

        by_file = {}
        prefixes = []
        layouts = []
        paths("app/**/*.erb").each do |file|
          collected = analyzer.send(:process_file_for_render_calls, file)
          next unless collected

          by_file[collected[:file]] = collected[:calls]
          prefixes.concat(collected[:dynamic_prefixes])
          layouts.concat(collected[:layout_references])
        end
        analyzer.analyze_from_collected(render_calls_by_file: by_file, dynamic_prefixes_from_erb: prefixes,
                                        layout_refs_from_erb: layouts)
      end

      # One render call as data.
      def render_call(call)
        { "file" => relative(call[:file]), "partial" => call[:partial], "location" => call[:location] }.compact
      end

      # The routes, the pages they render with the components on each, and
      # the edges with the ones a route resolves.
      def flows_report(calls, partials)
        by_file = calls.group_by(&:file)
        pages = @routes.filter_map do |route|
          template = "app/views/#{route["controller"]}/#{route["action"]}.html.erb"
          next unless @root.join(template).exist?

          route.merge("template" => template, "components" => page_components(template, by_file, partials["graph"]))
        end
        edges = edge_records.map { |edge| resolve_edge(edge) }
        { "routes" => @routes, "pages" => pages, "edges" => edges,
          "unresolved_kinds" => edges.reject { |edge| edge["to"] }.group_by { |edge| edge["kind"] }
                                     .transform_values(&:size) }
      end

      # The helpers a page renders: its template's calls and, through the
      # render graph, its partials' (each partial once).
      def page_components(template, by_file, graph)
        seen = []
        queue = [template]
        until queue.empty?
          file = queue.shift
          next if seen.include?(file)

          seen << file
          queue.concat(graph.fetch(file, []))
        end
        seen.flat_map { |file| by_file.fetch(file, []).map(&:helper) }.tally.sort_by { |helper, n| [-n, helper] }
            .map { |helper, n| { "helper" => helper, "call_sites" => n } }
      end

      # Every edge in the app's templates, helpers and controllers.
      def edge_records
        paths(EDGE_GLOB).flat_map do |path|
          Poetry::Core::Audit::Edges.scan(File.read(path, encoding: "UTF-8"), file: relative(path))
        end
      end

      # The edge with the route it resolves to, when its kind resolves: a
      # named helper by the route's name, a literal path by the route's
      # pattern (no dynamic segment), the submitting calls preferring the
      # POST route on that path.
      def resolve_edge(edge)
        route = case edge["kind"]
                when "path_helper"
                  name = edge["target"].sub(/_(?:path|url)\z/, "")
                  @routes.find { |candidate| candidate["name"] == name }
                when "literal_path"
                  path = edge["target"].split("?").first
                  candidates = @routes.select { |candidate| candidate["path"] == path }
                  verb = SUBMITTING_CALLS.include?(edge["call"]) ? "POST" : "GET"
                  candidates.find { |candidate| candidate["verb"] == verb } || candidates.first
                end
        route ? edge.merge("route" => route["name"], "to" => "#{route["controller"]}##{route["action"]}") : edge
      end

      # The headline numbers, every file's in one place.
      def summary(templates:, inventory:, tokens:, health:, partials:, flows:)
        busiest = tokens["font_sizes"]["templates"].first
        edges = flows["edges"]
        files = %w[summary inventory health flows].map { |name| "#{OUTPUT}/#{name}.json" }
        {
          "schema" => SCHEMA, "generated_at" => Time.now.utc.iso8601, "app" => @app,
          "templates" => templates.size, "ruby_files" => paths(RUBY_GLOB).size,
          "components" => { "used" => inventory["components"].size,
                            "call_sites" => inventory["components"].sum { |row| row["call_sites"] } },
          "coverage" => inventory["coverage"],
          "health" => { "errors" => health["errors"], "warnings" => health["warnings"],
                        "design_warnings" => health["design"]["warnings"] },
          "raw_colors" => { "unique" => tokens["raw_colors"].size,
                            "uses" => tokens["raw_colors"].sum { |row| row["uses"] } },
          "off_scale" => { "unique" => tokens["off_scale"].size,
                           "uses" => tokens["off_scale"].sum { |row| row["uses"] } },
          "font_sizes" => { "distinct" => tokens["font_sizes"]["distinct"],
                            "max_per_template" => busiest&.fetch("sizes")&.size || 0,
                            "template" => busiest&.fetch("template") },
          "icons" => { "distinct" => inventory["icons"].size, "uses" => inventory["icons"].sum { |row| row["uses"] } },
          "partials" => { "available" => partials["available"], "reason" => partials["reason"],
                          "unused" => partials["unused"].size, "unresolved" => partials["unresolved"].size,
                          "dynamic" => partials["dynamic"].size }.compact,
          "flows" => { "routes" => flows["routes"].size, "pages" => flows["pages"].size, "edges" => edges.size,
                       "resolved" => edges.count { |edge| edge["to"] },
                       "unresolved" => edges.count { |edge| !edge["to"] } },
          "files" => files + ["#{OUTPUT}/report.html"]
        }
      end

      # The report: Poetry's own components rendered through the app's own
      # renderer, the compiled stylesheet inlined, one file that opens from
      # disk.
      def report_html
        stylesheet = @compiled_css&.exist? ? @compiled_css.read : nil
        renderer.render(template: "poetry/ui/audit/report", layout: false,
                        assigns: { audit: @data, stylesheet: stylesheet })
      end

      # What renders the report: the app's own base controller (its helpers
      # included), found by name so the gem never names the host, or
      # Action Controller's base outside one.
      def renderer
        @renderer ||= ActionController::Base.descendants.find { |klass| klass.name == "ApplicationController" } ||
                      ActionController::Base
      end

      # Writes a file whole: beside, then into place.
      def atomic_write(path, content)
        staging = path.sub_ext("#{path.extname}.tmp")
        staging.write(content)
        staging.rename(path)
        path
      end
    end
  end
end
