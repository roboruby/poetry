# frozen_string_literal: true

# The StableId architectural gate (plan S1): proves in a real browser that
# key: gives Turbo morph the identity it needs - and that the unkeyed
# fallback keeps today's over-replace behavior (never false retention).
# Browser-gated like visual/axe (needs Chrome; not in the default gate).
namespace :test do
  desc "StableId gate: keyed components keep DOM identity across a Turbo morph reorder"
  task morph_identity: :"browser:assets" do
    session = poetry_ui_browser_session
    failures = []

    wait_ready = lambda do
      raise "gate page never booted" unless session.has_css?("html[data-poetry-ready]", wait: 10)
    end
    wait_order = lambda do |order|
      raise "morph never landed (#{order})" unless session.has_css?("#order-flag[data-order='#{order}']", wait: 10)
    end
    # The same-node probe: a JS PROPERTY (not attribute) survives only if
    # idiomorph MATCHED the node - a replaced node loses it, and morph's
    # attribute sync can't fake it.
    mark = "document.querySelector('#message_41 [data-slot=dropdown-menu-trigger]').__sgate = 'm41'"
    probe = "document.querySelector('#message_41 [data-slot=dropdown-menu-trigger]').__sgate"
    # Focus is NOT asserted (reordering detaches/reinserts, which blurs
    # in every browser regardless of pairing) and neither is input VALUE
    # (idiomorph deliberately syncs values to server truth - Turbo's
    # data-turbo-permanent is the tool for user-held input state). What
    # key identity actually preserves is the NODE: JS state, Stimulus
    # controller instances, everything riding the element object. The
    # id-less input probe additionally proves soft-matching inside the
    # keyed row's paired subtree.
    mark_note = "document.querySelector('#message_41 [data-role=note]').__sgate = 'n41'"
    note_probe = "document.querySelector('#message_41 [data-role=note]').__sgate"
    dup_ids = <<~JS
      (() => { const seen = {}; const dups = [];
        document.querySelectorAll('[id]').forEach(el => {
          if (seen[el.id]) dups.push(el.id); seen[el.id] = true; });
        return dups; })()
    JS

    # KEYED: identity follows the record across the reorder.
    session.visit("/sgate?keyed=1&order=asc")
    wait_ready.call
    session.execute_script(mark)
    session.execute_script(mark_note)
    session.find("#reorder").click
    wait_order.call("desc")
    failures << "keyed: trigger node was replaced (key identity did not pair the morph)" unless
      session.evaluate_script(probe) == "m41"
    failures << "keyed: the id-less input node was replaced (soft-match inside the paired row failed)" unless
      session.evaluate_script(note_probe) == "n41"
    dups = session.evaluate_script(dup_ids)
    failures << "keyed: duplicate DOM ids after morph: #{dups.uniq.join(", ")}" unless dups.empty?

    # UNKEYED: today's behavior, pinned - random ids force replacement
    # (over-replace, never false retention).
    session.visit("/sgate?keyed=0&order=asc")
    wait_ready.call
    session.execute_script(mark)
    session.execute_script(mark_note)
    session.find("#reorder").click
    wait_order.call("desc")
    failures << "unkeyed: node survived?! random ids should force replacement" if
      session.evaluate_script(probe) == "m41"
    # The id-less input SURVIVES even unkeyed: the host's stable row id
    # (message_41) pairs the row, and soft-matching keeps id-less
    # children. The damage radius of unkeyed poetry components is
    # exactly the component's own random-id subtree - pinned here.
    failures << "unkeyed: the row-level soft-match regressed (id-less input was replaced)" unless
      session.evaluate_script(note_probe) == "n41"

    abort "StableId gate FAILED:\n  #{failures.join("\n  ")}" if failures.any?

    puts "StableId gate: keyed identity follows the record across a Turbo morph reorder; " \
         "unkeyed replaces (today's behavior, pinned); no duplicate ids"
  end
end
