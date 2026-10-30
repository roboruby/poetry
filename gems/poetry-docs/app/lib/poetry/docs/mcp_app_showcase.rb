# frozen_string_literal: true

module Poetry
  module Docs
    # The MCP App demo: a plan picker the docs' own MCP server serves as a
    # `ui://` resource, rendered through the docs' views. A host (Claude
    # Desktop through mcp-remote, or the demo page's host simulator) calls
    # `show_plans`, loads the document into its sandbox, and the page fills
    # its region from the fragment the result carries; "Choose" calls the
    # app-only `choose_plan` from inside the page. Same bytes every run.
    module McpAppShowcase
      PLANS = [
        { "id" => "starter", "name" => "Starter", "monthly" => 19, "yearly" => 190, "seats" => 3,
          "note" => "Solo and small teams" },
        { "id" => "pro", "name" => "Pro", "monthly" => 49, "yearly" => 490, "seats" => 10, "note" => "Growing teams" },
        { "id" => "team", "name" => "Team", "monthly" => 99, "yearly" => 990, "seats" => 50,
          "note" => "Whole departments" }
      ].freeze

      # The document: the docs' stylesheet and importmap from the request's
      # own origin, the default theme's class on the page.
      DOCUMENT = Poetry::Agent::Apps::Document.new(
        uri: "ui://poetry-docs/plans", name: "plans", title: "Plans",
        description: "The plan picker: a table of plans with a recommendation, and a choice made inside the page",
        template: "poetry/docs/mcp_app/plans", origin: :request, stylesheets: [ "poetry_docs" ],
        entrypoint: "poetry_docs/application", html: { class: "style-default" }, prefers_border: true,
        renderer: Poetry::Docs::ApplicationController
      )

      module_function

      # The docs' MCP server with the app beside the roster.
      #
      # @param app_root [String] the docs engine's root
      # @return [Poetry::Agent::MCP::Server]
      def server(app_root:)
        Poetry::Agent::MCP::Bundled.server(app_root: app_root).apps(DOCUMENT).tap { |server| define_tools(server.mcp) }
      end

      # The two tools on the gem's server: the model's, and the page's.
      #
      # @param mcp [MCP::Server] the gem's server
      def define_tools(mcp)
        mcp.define_tool(
          name: "show_plans", title: "Show plans",
          description: "Shows the pricing plans as an interactive table and recommends one for the team size.",
          input_schema: { type: "object", properties: { team_size: { type: "integer", description: "People on the team" } } },
          meta: DOCUMENT.tool_meta
        ) { |team_size: nil, **| McpAppShowcase.plans_result(team_size: team_size).to_response }

        mcp.define_tool(
          name: "choose_plan", title: "Choose a plan",
          description: "Records the plan the user picked in the plans app.",
          input_schema: { type: "object", required: [ "plan" ],
                          properties: { plan: { type: "string", enum: PLANS.map { |plan| plan["id"] } },
                                        billing: { type: "string", enum: %w[monthly yearly] } } },
          meta: DOCUMENT.tool_meta(visibility: [ "app" ])
        ) { |plan:, billing: "monthly", **| McpAppShowcase.chosen_result(plan: plan, billing: billing).to_response }
      end

      # The plan that fits a team.
      # @param team_size [Integer, nil]
      # @return [Hash]
      def recommended(team_size)
        PLANS.find { |plan| plan["seats"] >= team_size.to_i } || PLANS.last
      end

      # The show_plans result: a sentence per plan for the model, the plans
      # as data, and the table as a fragment for the page.
      # @param team_size [Integer, nil]
      # @return [Poetry::Agent::Apps::Result]
      def plans_result(team_size:)
        pick = recommended(team_size)
        lines = PLANS.map { |plan| "#{plan["name"]}: $#{plan["monthly"]}/month or $#{plan["yearly"]}/year, up to #{plan["seats"]} seats" }
        lines << "Recommended#{" for #{team_size}" if team_size}: #{pick["name"]}."
        table = Poetry::Agent::Apps.fragment("plans", partial: "poetry/docs/mcp_app/plans_table",
                                             locals: { plans: PLANS, recommended: pick, team_size: team_size },
                                             renderer: Poetry::Docs::ApplicationController)
        Poetry::Agent::Apps.result(text: lines.join("\n"), data: { "plans" => PLANS, "recommended" => pick["id"] },
                                   fragments: [ table ])
      end

      # The choose_plan result: the confirmation for the model and the page.
      # @param plan [String] the plan id
      # @param billing [String] monthly or yearly
      # @return [Poetry::Agent::Apps::Result]
      def chosen_result(plan:, billing:)
        chosen = PLANS.find { |candidate| candidate["id"] == plan } || PLANS.first
        card = Poetry::Agent::Apps.fragment("plans", partial: "poetry/docs/mcp_app/chosen",
                                            locals: { plan: chosen, billing: billing },
                                            renderer: Poetry::Docs::ApplicationController)
        Poetry::Agent::Apps.result(text: "The user chose #{chosen["name"]} (#{billing}).",
                                   data: { "chosen" => chosen["id"], "billing" => billing }, fragments: [ card ])
      end
    end
  end
end
