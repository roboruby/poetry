# frozen_string_literal: true

require_relative "runner"

module Poetry
  module Eval
    # The holdout stratum (a review borrow): eight briefs
    # RESERVED for grading changes to the agent surfaces (skills, AGENTS.md,
    # llms text, MCP descriptions). The standing 31 briefs are the corpus
    # those surfaces get tuned against over time; a doc edit graded on them
    # grades its own training set. These eight exist to answer "did the
    # edit generalize?" and nothing else.
    #
    # DOCTRINE (the whole point - break these and the stratum is spent):
    # 1. NEVER tune against them: no skill/doc/prompt edit may cite a
    #    holdout failure as its motivation. Evidence comes from the
    #    standing set; the holdout only VALIDATES.
    # 2. Run them only when a surface change claims improvement: full
    #    benchmark machinery via POETRY_BENCH_SPEC=holdout, before/after
    #    the change, both arms.
    # 3. Report every run in the decision log, including the losses. An
    #    unreported holdout run is a tuned holdout.
    # Families deliberately echo the standing set at one remove; briefs are
    # hermetic (no house name) like every generation surface.
    class Holdout
      Gate = Runner::Gate

      TASKS = {
        "audit_log" => {
          "description" => "An audit log: entries grouped under day headings, each entry with an " \
                           "actor avatar, an action summary, a timestamp, and a details disclosure",
          "gates" => [
            Gate.new(:grouped_list, :cross_arm, ->(doc, _html) { doc.css("ul, ol, table, [role=list]").any? }),
            Gate.new(:day_headings, :cross_arm, ->(doc, _html) { doc.css("h2, h3, h4").size >= 2 }),
            Gate.new(:disclosure_semantics, :cross_arm, lambda { |doc, _html|
              doc.css("details, [aria-expanded]").any?
            }),
            Gate.new(:machine_time, :cross_arm, ->(doc, _html) { doc.css("time[datetime]").any? })
          ]
        },
        "billing_summary" => {
          "description" => "A billing summary panel: current plan name and price, renewal date, a " \
                           "payment-method row with an update action, and a link to past invoices",
          "gates" => [
            Gate.new(:heading_present, :cross_arm, ->(doc, _html) { doc.css("h1, h2, h3").any? }),
            Gate.new(:update_action, :cross_arm, ->(doc, _html) { doc.css("button, a").size >= 2 }),
            Gate.new(:invoices_link, :cross_arm, lambda { |doc, _html|
              doc.css("a").any? { |a| a.text.downcase.include?("invoice") }
            })
          ]
        },
        "team_invite" => {
          "description" => "An 'Invite teammates' section: an email field with an add action, a " \
                           "role select (Admin / Member / Viewer), and a pending-invites list with " \
                           "revoke actions",
          "gates" => [
            Gate.new(:email_field_labelled, :cross_arm, lambda { |doc, _html|
              input = doc.css("input[type=email], input[name*=email i]").first
              input && (doc.css("label[for='#{input["id"]}']").any? || input["aria-label"])
            }),
            Gate.new(:role_choice, :cross_arm, lambda { |doc, _html|
              doc.css("select, [role=combobox], [role=listbox], [role=radiogroup]").any?
            }),
            Gate.new(:revoke_actions, :cross_arm, lambda { |doc, _html|
              doc.css("button, a").count { |el| el.text.downcase.include?("revoke") } >= 1
            })
          ]
        },
        "notification_center" => {
          "description" => "A notifications control: a bell button with an unread-count badge " \
                           "opening a panel of notifications grouped by day, with a mark-all-read action",
          "gates" => [
            Gate.new(:trigger_labelled, :cross_arm, lambda { |doc, _html|
              trigger = doc.css("button").first
              trigger && (trigger.text.strip.length.positive? || trigger["aria-label"])
            }),
            Gate.new(:popup_semantics, :cross_arm, lambda { |doc, _html|
              doc.css("[popover], dialog, [role=dialog], [aria-expanded], details").any?
            }),
            Gate.new(:mark_all_read, :cross_arm, lambda { |doc, _html|
              doc.css("button, a").any? { |el| el.text.downcase.include?("read") }
            })
          ]
        },
        "api_keys" => {
          "description" => "An API keys table: key name, masked token, created date, last-used " \
                           "date, a revoke action per row, and a create-key button above the table",
          "gates" => [
            Gate.new(:real_table, :cross_arm, ->(doc, _html) { doc.css("table th").size >= 3 }),
            Gate.new(:masked_tokens, :cross_arm, ->(_doc, html) { html.match?(/[•*]{4,}|•{4,}/) }),
            Gate.new(:row_actions, :cross_arm, lambda { |doc, _html|
              doc.css("td button, td a").any?
            }),
            Gate.new(:create_action, :cross_arm, lambda { |doc, _html|
              doc.css("button, a").any? { |el| el.text.downcase.match?(/create|new key/) }
            })
          ]
        },
        "onboarding_checklist" => {
          "description" => "A getting-started checklist: four setup steps with done/pending states, " \
                           "an overall progress indicator, and a dismiss control",
          "gates" => [
            Gate.new(:four_steps, :cross_arm, ->(doc, _html) { doc.css("li").size >= 4 }),
            Gate.new(:progress_semantics, :cross_arm, lambda { |doc, _html|
              doc.css("progress, [role=progressbar], [aria-valuenow]").any?
            }),
            Gate.new(:dismissable, :cross_arm, lambda { |doc, _html|
              doc.css("button").any? do |el|
                el.text.downcase.match?(/dismiss|close|hide/) || el["aria-label"].to_s.downcase.match?(/dismiss|close/)
              end
            })
          ]
        },
        "search_results" => {
          "description" => "A search results section: a summary line for the query, removable " \
                           "filter chips, result entries with title / snippet / source path, and a " \
                           "no-results variant",
          "gates" => [
            Gate.new(:result_headings, :cross_arm, ->(doc, _html) { doc.css("h2, h3, h4, a h2, a h3").size >= 2 }),
            Gate.new(:removable_chips, :cross_arm, lambda { |doc, _html|
              doc.css("button").size >= 2
            }),
            Gate.new(:empty_variant, :cross_arm, lambda { |_doc, html|
              html.downcase.match?(/no results|nothing (?:found|matched)/)
            })
          ]
        },
        "status_banner" => {
          "description" => "A degraded-service banner: warning tone, an incident title, a " \
                           "started-at timestamp, a status-page link, and a dismiss control",
          "gates" => [
            Gate.new(:status_semantics, :cross_arm, lambda { |doc, _html|
              doc.css("[role=status], [role=alert], [aria-live]").any?
            }),
            Gate.new(:machine_time, :cross_arm, ->(doc, _html) { doc.css("time[datetime]").any? }),
            Gate.new(:status_link, :cross_arm, lambda { |doc, _html|
              doc.css("a").any? { |a| a.text.downcase.include?("status") }
            }),
            Gate.new(:dismiss_control, :cross_arm, lambda { |doc, _html|
              doc.css("button").any? do |el|
                el.text.downcase.match?(/dismiss|close/) || el["aria-label"].to_s.downcase.match?(/dismiss|close/)
              end
            })
          ]
        }
      }.freeze
    end
  end
end
