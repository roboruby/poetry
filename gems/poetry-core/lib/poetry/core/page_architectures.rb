# frozen_string_literal: true

module Poetry
  module Core
    # The page-architecture catalog: the data the build_page
    # workflow's `plan` step matches an intent against. Each archetype is a
    # page SHAPE - purpose, section order, the states a real screen must
    # handle, the edge cases that bite, the components it draws on, and the
    # vetted block to START from when one covers it. This is the plan step's
    # answer to a measured failure: naming the design
    # skill and the block catalog does not move composition on its own; the
    # missing piece is directed retrieval at PLAN time, before any ERB.
    #
    # Product framing: the eval measures whether guided planning
    # moves the composition score, but the catalog exists for the person
    # building the page - it is the answer to "what does a real <kind of>
    # screen need", stated once, correctly.
    #
    # SEED: this ships the archetypes anchored to poetry's eight blocks plus
    # the universal page types every app needs. It is deliberately a seed
    # (the target is ~50); it grows as blocks and evidence
    # accrue. A brief that matches nothing is told so and routed to compose
    # + the five mechanics, never silently dropped.
    module PageArchitectures
      # Each entry: name, title, purpose, keywords (matched, weighted x2),
      # sections (ordered macrostructure), states (what a real screen shows
      # beyond the happy path), edge_cases (what bites), components, and
      # block (the vetted starting block, or nil when none covers it yet).
      ALL = [
        {
          "name" => "records-index",
          "title" => "Records index",
          "purpose" => "A browsable, filterable list of many records - the workhorse admin screen.",
          "keywords" => %w[index list listing table records directory browse catalog invoices orders
                           users customers management filter pagination],
          "sections" => ["Page header (title + count + primary 'New' action)",
                         "Filter/search bar (the controls that narrow the set)",
                         "The table (sortable columns, row-level actions in the last column)",
                         "Pagination + result count footer"],
          "states" => ["Loading: skeleton rows, not a spinner over a blank table",
                       "Empty - NO records yet: an empty state with the 'New' call to action",
                       "Empty - filter matched nothing: a distinct 'no matches, clear filters' message",
                       "Populated: a realistic distribution (mostly one status, a few exceptions)"],
          "edge_cases" => ["Long cell text: truncate with a title, never wrap the row to three lines",
                           "One page of results: hide pagination, keep the count",
                           "Row actions on mobile: collapse the last column into a menu",
                           "Bulk selection turns this into the action-bar archetype"],
          "components" => %w[table badge button button_group input_group native_select pagination label icon],
          "block" => "data-index"
        },
        {
          "name" => "bulk-actions-table",
          "title" => "Table with bulk actions",
          "purpose" => "A records table where rows are selectable and act on in batches.",
          "keywords" => %w[bulk selection batch selected archive delete multi-select checkbox
                           actions action bar rows],
          "sections" => ["The records table with a leading selection column",
                         "A contextual action bar that appears only when rows are selected",
                         "The batch actions (archive / delete / export) with a selected-count label"],
          "states" => ["Nothing selected: the action bar is absent, the table reads normally",
                       "Some selected: the bar shows the count + the batch actions",
                       "All selected across pages: offer 'select all N', distinct from 'all on this page'",
                       "A destructive batch action confirms before running (AlertDialog)"],
          "edge_cases" => ["The action bar must not cover the last row - it floats, it does not overlap",
                           "Selection survives sort but is cleared by a filter change (say so)",
                           "A single-row action still lives in the row, not only the bar"],
          "components" => %w[data_table table button icon badge],
          "block" => "action-bar"
        },
        {
          "name" => "admin-dashboard",
          "title" => "Admin dashboard / app shell",
          "purpose" => "The signed-in workspace: persistent chrome around a content area of stats and panels.",
          "keywords" => %w[dashboard shell layout sidebar workspace admin console overview stats
                           chrome home analytics metrics],
          "sections" => ["Sidebar (primary nav, current section marked)",
                         "Top bar (breadcrumb + user menu + global actions)",
                         "A KPI row (Stat cards, one number each)",
                         "Content panels (charts, recent activity, tables) on a grid"],
          "states" => ["First run: zero data - each panel shows its own empty state, not a blank grid",
                       "Loading: skeleton the panels independently so the shell stays put",
                       "Collapsed sidebar on narrow viewports (the shell owns the breakpoint)"],
          "edge_cases" => ["The content area is already padded - blocks composed INTO it drop their outer wrapper",
                           "One primary action in the top bar, everything else outline/ghost",
                           "Deep nav: mark the active trail, do not just highlight the leaf"],
          "components" => %w[sidebar breadcrumb avatar card separator button icon stat],
          "block" => "app-shell"
        },
        {
          "name" => "settings",
          "title" => "Settings page",
          "purpose" => "Grouped, independently-saved panels of preferences and account controls.",
          "keywords" => %w[settings section panel account preferences profile configuration
                           notifications security billing],
          "sections" => ["Page header (what these settings govern)",
                         "One section-card per group (Profile / Notifications / Security / Danger)",
                         "Each card: a heading, its fields, and its own save affordance",
                         "A danger zone LAST, visually separated"],
          "states" => ["Pristine vs dirty: the save action enables only when something changed",
                       "Saving: the one button that submits shows progress, the rest stay usable",
                       "Saved: a quiet confirmation, not a modal"],
          "edge_cases" => ["The danger zone is its own destructive-panel archetype, not a red button in a card",
                           "Never mix badge treatments across the cards (one status family)",
                           "Sensitive fields (API keys) use the reveal/copy pattern, masked at rest"],
          "components" => %w[card badge link icon label input switch button separator],
          "block" => "section-card"
        },
        {
          "name" => "record-detail",
          "title" => "Record detail page",
          "purpose" => "Everything about one record: its facts, its related lists, its actions.",
          "keywords" => %w[detail show record profile summary overview single view page],
          "sections" => ["Page header with breadcrumb back to the index + record-level actions",
                         "A facts panel (MetadataList: label:value pairs, status as a Badge)",
                         "Related lists (line items, activity, comments) as their own sections",
                         "Destructive actions fenced at the bottom"],
          "states" => ["Loading: skeleton the header + facts, not a full-page spinner",
                       "Missing/deleted record: a 404-style empty state, not a broken page",
                       "Partial data: show the field label with an em-dash placeholder, keep alignment"],
          "edge_cases" => ["Status belongs in ONE place (the header badge), not repeated per section",
                           "Related lists that are empty say so inline, they do not vanish",
                           "The primary action reflects state (Publish vs Unpublish), it is not static"],
          "components" => %w[breadcrumb metadata_list badge card button separator icon],
          "block" => "page-header"
        },
        {
          "name" => "create-edit-form",
          "title" => "Create / edit form",
          "purpose" => "A focused form that creates or updates one record, with real validation.",
          "keywords" => %w[form create edit new update fields validation submit input save
                           create-edit],
          "sections" => ["Page (or dialog) header naming the task",
                         "Fields grouped by meaning inside a section-card, in the order a human fills them",
                         "Inline help under complex fields",
                         "A sticky action row: primary Save + a Cancel that does not look primary"],
          "states" => ["Pristine, dirty, submitting (button progress + disabled resubmit)",
                       "Field-level errors anchored to their field, with a summary if many",
                       "Server error on submit: a form-level alert, the entered values preserved",
                       "Success: navigate or confirm, do not silently reset"],
          "edge_cases" => ["Required vs optional is marked once, consistently",
                           "Choosing that writes a value is a Select/Combobox, never a menu (see deciding)",
                           "Unsaved-changes guard on navigate-away for long forms"],
          "components" => %w[card label input textarea select combobox switch button alert icon],
          "block" => "section-card"
        },
        {
          "name" => "wizard-checkout",
          "title" => "Multi-step wizard / checkout",
          "purpose" => "A long task broken into ordered steps with visible progress and a review.",
          "keywords" => %w[stepper wizard steps checkout onboarding progress multi-step flow
                           cart payment review],
          "sections" => ["The step indicator (where you are, what remains)",
                         "The current step's fields, one concern per step",
                         "A review step summarizing every prior choice before commit",
                         "Back / Continue controls; the final step's action is the commit"],
          "states" => ["Per-step validation gates Continue - you cannot skip ahead past errors",
                       "Returning to a completed step preserves its answers",
                       "Submitting the final step: progress, and it cannot be double-fired",
                       "Payment/commit failure returns to the review step with the error, not step 1"],
          "edge_cases" => ["Do not animate keyboard-initiated step changes (perception floor)",
                           "The indicator reflects real completion, not just the highest step visited",
                           "Mobile: the indicator collapses to 'Step 2 of 4', the fields get full width"],
          "components" => %w[card button icon label input separator],
          "block" => "stepper"
        },
        {
          "name" => "marketing-landing",
          "title" => "Marketing / landing page",
          "purpose" => "A public page that explains and converts: hero, proof, call to action.",
          "keywords" => %w[landing marketing hero home public site navbar features testimonials
                           cta convert homepage],
          "sections" => ["Top nav (logo, a few links, one primary CTA)",
                         "Hero (one claim, one sub-line, one primary + one secondary action)",
                         "Feature/benefit sections (alternating, contained)",
                         "Social proof, then a closing CTA band, then a footer"],
          "states" => ["Signed-out vs signed-in nav (the CTA changes to 'Dashboard')",
                       "Responsive: the nav collapses to a sheet, the hero stacks"],
          "edge_cases" => ["One primary action per section - competing CTAs kill conversion and hierarchy",
                           "Marketing copy still respects the heading ladder for SEO + a11y",
                           "The theme carries the personality; do not reach for per-instance gradients"],
          "components" => %w[navigation_menu button link icon card badge],
          "block" => "top-nav"
        },
        {
          "name" => "pricing",
          "title" => "Pricing page",
          "purpose" => "Comparable plan tiers with one recommended, driving a single choice.",
          "keywords" => %w[pricing plans tiers subscription billing compare upgrade plan price],
          "sections" => ["Top nav",
                         "A tier row (3-4 cards), the recommended one visually lifted",
                         "A feature comparison (per-card lists, or a comparison table below)",
                         "An FAQ / closing CTA"],
          "states" => ["Monthly/annual toggle recomputes every card's price",
                       "The current plan is marked when signed in ('Your plan'), its CTA disabled"],
          "edge_cases" => ["Exactly one card is emphasized - two 'most popular' badges is a hierarchy bug",
                           "Equal-height cards regardless of feature-list length",
                           "The recommended card's button is the only filled primary in the row"],
          "components" => %w[card badge button separator icon link toggle_group],
          "block" => "top-nav"
        },
        {
          "name" => "auth",
          "title" => "Sign-in / sign-up screen",
          "purpose" => "A centered, low-chrome screen that authenticates and nothing else.",
          "keywords" => %w[auth login signin signup register password authentication credentials
                           sign-in sign-up forgot],
          "sections" => ["A centered card: brand mark, title, the fields",
                         "Primary submit, then secondary provider buttons (outline)",
                         "A footer link to the opposite flow (sign up <-> sign in) + forgot-password"],
          "states" => ["Submitting: the primary button shows progress, inputs lock",
                       "Auth failure: a form-level alert ('check your details'), never per-field blame",
                       "Rate-limited / locked: a distinct message, not the generic error"],
          "edge_cases" => ["No app chrome here - this is the one screen with no sidebar/top-nav",
                           "Password field carries a reveal toggle; caps-lock hint is a nice touch",
                           "Provider buttons never outrank the primary submit"],
          "components" => %w[card label input button separator link alert icon],
          "block" => nil
        },
        {
          "name" => "empty-first-run",
          "title" => "Empty state / first run",
          "purpose" => "The zero-data screen that turns 'nothing here' into a first action.",
          "keywords" => %w[empty first-run onboarding zero blank getting-started nothing new
                           empty-state placeholder],
          "sections" => ["A centered empty state: an icon, a one-line explanation of what goes here",
                         "The single primary action that creates the first item",
                         "Optionally a secondary 'learn more' / import path"],
          "states" => ["True empty (never had data) vs filtered-empty (had data, filter hid it) differ in copy",
                       "Loading-into-empty: skeleton first, resolve to the empty state, no flicker"],
          "edge_cases" => ["This is a SECTION pattern as much as a page - the same shape sits inside a panel",
                           "One action - do not offer five ways to start",
                           "Do not mistake an error for empty; a failed load has its own state"],
          "components" => %w[card button icon link],
          "block" => nil
        },
        {
          "name" => "confirm-destructive",
          "title" => "Destructive confirmation",
          "purpose" => "The surface that makes an irreversible action deliberate and clear.",
          "keywords" => %w[delete destroy remove deactivate irreversible permanently danger
                           destructive confirm deletion],
          "sections" => ["A tinted destructive boundary (panel or AlertDialog)",
                         "Icon + title only on the tint; consequences in AA-clean muted copy below",
                         "A confirm action (labeled with the verb: 'Delete project') + a plain Cancel"],
          "states" => ["Requires intent: a type-to-confirm field for high-stakes deletes",
                       "Confirming: progress on the destructive button, Cancel stays available",
                       "Failure: the error shows in place, the record is untouched"],
          "edge_cases" => ["Description copy on the destructive tint fails AA - keep prose off the tint",
                           "The default focus is Cancel, not Confirm, for irreversible acts",
                           "AlertDialog (no light-dismiss), never a plain Dialog, for destruction"],
          "components" => %w[alert button icon],
          "block" => "destructive-panel"
        },
        {
          "name" => "profile-account",
          "title" => "Profile / account overview",
          "purpose" => "A read-first page about one person or org, with edit paths to settings.",
          "keywords" => %w[profile account overview member team org organization bio details
                           user avatar],
          "sections" => ["A header identity band (avatar, name, role, primary action)",
                         "A facts panel (MetadataList) of the account's key attributes",
                         "Section cards for related areas (team, activity, connected apps)"],
          "states" => ["Own profile (edit affordances) vs someone else's (read-only)",
                       "Incomplete profile: prompt to finish, do not show blank fields as errors"],
          "edge_cases" => ["Avatar fallback to initials when no image - never a broken img",
                           "Status/role shown once as a Badge, in the identity band",
                           "Editing routes to the settings archetype, it does not inline every field"],
          "components" => %w[avatar metadata_list badge card button separator icon link],
          "block" => "section-card"
        }
      ].freeze

      module_function

      def all
        ALL
      end

      # Score every archetype against a pre-stemmed token set (the Server's
      # brief_tokens output). Curated keywords count double; title/purpose
      # tokens count once - the same weighting compose uses for blocks, so
      # planning and routing rank intents the same way. Returns
      # [entry, score] sorted best-first, ties broken by name.
      def scored(tokens)
        ALL.map { |entry| [entry, score(entry, tokens)] }
           .sort_by { |entry, score| [-score, entry["name"]] }
      end

      def score(entry, tokens)
        keywords = (entry["keywords"] || []).to_set { |word| word.delete_suffix("s") }
        corpus = "#{entry["title"]} #{entry["purpose"]}".downcase
                                                        .scan(/[a-z0-9][a-z0-9_-]+/)
                                                        .to_set { |token| token.delete_suffix("s") }
        tokens.sum do |token|
          if keywords.include?(token) then 2
          elsif corpus.include?(token) then 1
          else 0
          end
        end
      end
    end
  end
end
