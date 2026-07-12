# frozen_string_literal: true

require_relative "runner"

module Poetry
  module Eval
    # The page-scale companion gate: twelve briefs at the altitude
    # the standing benchmark is 71% blind to - whole screens, not
    # components. Archetypes are drawn from the standard surface set every
    # B2B SaaS product ships (dashboard/settings/billing/members/login/
    # pricing/audit/detail/integrations/inbox/search/status) rather than
    # authored to fit poetry's blocks: roughly half sit OUTSIDE block
    # coverage on purpose - the claim under test is page-scale value, not
    # block-lookup luck. Briefs are user-story voice, zero block
    # vocabulary, frozen verbatim in the pre-registration.
    #
    # This gate runs ALONGSIDE the standing 31-brief benchmark and NEVER
    # replaces its headline (pre-registered, permanent).
    #
    # Gates are deliberately UNIFORM across all twelve tasks (renders +
    # has_heading + the universal pair): the deterministic tier here is
    # delivery sanity, the measure is the judge - and uniform gates leave
    # no room for per-task gate tailoring.
    module Pagescale
      RENDERS = Runner::Gate.new(:renders, :cross_arm, lambda { |doc, _html|
        doc.css("div, section, main, header, table, form, ul, article").size >= 5
      })
      HAS_HEADING = Runner::Gate.new(:has_heading, :cross_arm, lambda { |doc, _html|
        doc.css("h1, h2").any? { |heading| heading.text.strip.length.positive? }
      })
      GATES = [RENDERS, HAS_HEADING].freeze

      BRIEFS = {
        "analytics_overview" =>
          "The analytics overview for a project-management workspace: headline numbers for active " \
          "projects, tasks completed this week, overdue items and team velocity, a recent-activity " \
          "list, and a per-project progress summary - a working product screen, not a demo",
        "billing_settings" =>
          "The billing page for a team workspace: the current plan with its renewal date, the " \
          "payment method on file, usage this period against plan limits, and an invoice history " \
          "with amounts, payment status and downloadable receipts",
        "team_members" =>
          "The members page of a workspace admin area: invite a teammate by email with a role " \
          "choice, a searchable member list showing avatar, name, role and last-active, and " \
          "pending invitations that can be resent or revoked",
        "login" =>
          "The sign-in screen for a business app: email and password with a forgot-password link, " \
          "a single-sign-on alternative, and a request-access path for new users - branded, " \
          "centered, production-ready",
        "onboarding_checklist" =>
          "The first-run screen after a user creates a workspace: a short welcome, three setup " \
          "steps with completion states (connect a repository, invite the team, create the first " \
          "project), and a way to skip for now",
        "pricing" =>
          "The public pricing page: three tiers with monthly prices and feature lists, one " \
          "recommended plan visually emphasized, an enterprise contact option, and four common " \
          "billing questions answered at the bottom",
        "audit_log" =>
          "The audit log for a workspace: a filterable list of security-relevant events - who did " \
          "what, when, and from where - grouped by day, with severity indicated and an export " \
          "affordance",
        "project_detail" =>
          "A single project's page: name, status and description up top with edit and archive " \
          "actions, owner and key dates, a milestone timeline, and the five most recent tasks " \
          "with assignees and due dates",
        "integrations" =>
          "The integrations page of a SaaS product: currently connected services with health " \
          "status and a manage action, and a catalog of available integrations grouped by " \
          "category, each with a short description and a connect button",
        "activity_inbox" =>
          "The activity inbox: a stream of mentions, assignments and status changes with unread " \
          "indicators, per-item actions to mark read or open, a filter by type, and an " \
          "all-caught-up state at the end",
        "search_results" =>
          "The global search results page for the query 'deployment': matches grouped across " \
          "projects, documents and people, each result with a context snippet and metadata, " \
          "per-group result counts, and a helpful message for one group with no matches",
        "status_page" =>
          "The public status page for a hosted product: an overall status banner, each service's " \
          "current state with uptime over the last 90 days, an active incident with timeline " \
          "updates, and a way to subscribe to updates"
      }.freeze

      TASKS = BRIEFS.transform_values do |description|
        { "description" => description, "gates" => GATES }
      end.freeze
    end
  end
end
