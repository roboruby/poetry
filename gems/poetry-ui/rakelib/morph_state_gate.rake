# frozen_string_literal: true

# The morph guard gate: proves in a real browser that the state the client
# changes on a keyed page survives a Turbo morphing refresh - the selected
# tab, a typed value, an expanded disclosure, a modal dialog - while a
# change the server made on purpose (the details cookie) still lands, and
# that a dialog closes on its own form's successful submission. Two refresh
# paths: the dialog's form posting and redirecting back, and a stream-style
# refresh (Turbo.session.refresh). Browser-gated like morph_identity.
namespace :test do
  desc "Morph state gate: client-changed state survives a Turbo morph, server changes still land"
  task morph_state: :"browser:assets" do
    session = poetry_ui_browser_session
    failures = []
    wait_ready = lambda do
      raise "gate page never booted" unless session.has_css?("html[data-poetry-ready]", wait: 10)
    end
    # The page's own counters: morphs landed, and what the dialog saw.
    morphs = -> { session.evaluate_script("window.__mgateMorphs || 0") }
    wait_morphs = lambda do |count|
      Timeout.timeout(10) { sleep 0.05 until morphs.call >= count }
    rescue Timeout::Error
      raise "morph #{count} never landed (#{morphs.call} so far)"
    end
    state = <<~JS
      (() => {
        const dialog = document.getElementById("gate-dialog-content")
        return {
          tabTwo: document.getElementById("gate-tabs-trigger-two").getAttribute("aria-selected"),
          panelTwoHidden: document.getElementById("gate-tabs-panel-two").hidden,
          input: document.getElementById("gate-input").value,
          localOpen: document.getElementById("gate-local").hasAttribute("data-open"),
          localBodyHidden: document.getElementById("gate-local-content").hidden,
          detailsOpen: document.getElementById("gate-details").hasAttribute("data-open"),
          dialogOpen: dialog.open,
          dialogModal: dialog.matches(":modal"),
          details: document.getElementById("details-flag").dataset.details
        }
      })()
    JS
    instrument = <<~JS
      window.__mgateMorphs = 0; window.__mgateLog = []
      const log = (entry) => window.__mgateLog.push(entry)
      document.addEventListener("turbo:morph", () => { window.__mgateMorphs += 1; log("morph") })
      document.addEventListener("turbo:render", (e) => log("render:" + (e.detail && e.detail.renderMethod)))
      document.addEventListener("turbo:before-cache", () => log("before-cache"))
      document.addEventListener("turbo:before-morph-element", (e) => {
        if (e.target.id === "gate-dialog-content") log("dialog-element:" + (e.defaultPrevented ? "skipped" : "morphed"))
      })
      document.addEventListener("turbo:before-morph-attribute", (e) => {
        if (e.target.id === "gate-dialog-content") log(e.detail.attributeName + ":" + e.detail.mutationType + ":" + (e.defaultPrevented ? "kept" : "synced"))
      })
      document.getElementById("gate-dialog-content").addEventListener("close", () => log("dialog-close"))
    JS
    interact = <<~JS
      document.getElementById("gate-tabs-trigger-two").click();
      const input = document.getElementById("gate-input");
      input.value = "typed"; input.dispatchEvent(new Event("input", { bubbles: true }));
      document.querySelector("#gate-local [data-slot=collapsible-trigger]").click();
    JS
    open_dialog = "[...document.querySelectorAll('button')].find((b) => b.textContent.trim() === 'Open dialog').click()"

    session.visit("/mgate")
    wait_ready.call
    session.execute_script(instrument)
    session.execute_script(interact)
    session.execute_script(open_dialog)
    raise "setup: the dialog did not open" unless session.has_css?("#gate-dialog-content[open]", wait: 5)

    before = session.evaluate_script(state)
    raise "setup: the page did not take the client's state (#{before})" unless
      before["tabTwo"] == "true" && before["input"] == "typed" && before["localOpen"]

    # Path 1: the dialog's own form posts and redirects back - a morph
    # refresh. The client's tab, value and disclosure survive, the server's
    # cookie-driven disclosure opens, the dialog closes (its own submit,
    # through its exit animation).
    session.execute_script("document.getElementById('gate-save').click()")
    wait_morphs.call(1)
    raise "form path: the cookie never reached the page" unless
      session.has_css?("#details-flag[data-details='1']", wait: 10)

    closed = session.has_no_css?("#gate-dialog-content[open]", wait: 5)
    after = session.evaluate_script(state)
    failures << "form path: tab two was reset" unless after["tabTwo"] == "true" && after["panelTwoHidden"] == false
    failures << "form path: the typed value was reset" unless after["input"] == "typed"
    failures << "form path: the disclosure closed" unless after["localOpen"] && after["localBodyHidden"] == false
    failures << "form path: the server's disclosure did not open (a server change was blocked)" unless
      after["detailsOpen"]
    failures << "form path: the dialog stayed open after its own submit" unless closed

    # Path 2: a stream-style refresh with the dialog open again - no
    # snapshot, no before-cache close - keeps the modal dialog and the rest.
    session.execute_script(open_dialog)
    raise "refresh path: the dialog did not reopen" unless session.has_css?("#gate-dialog-content[open]", wait: 5)

    landed = morphs.call
    session.execute_script("Turbo.session.refresh(location.href)")
    wait_morphs.call(landed + 1)
    final = session.evaluate_script(state)
    failures << "refresh path: the modal dialog closed" unless final["dialogOpen"] && final["dialogModal"]
    failures << "refresh path: tab two was reset" unless final["tabTwo"] == "true" && final["panelTwoHidden"] == false
    failures << "refresh path: the typed value was reset" unless final["input"] == "typed"
    failures << "refresh path: the expanded disclosure closed" unless final["localOpen"]
    failures << "refresh path: the server's disclosure closed" unless final["detailsOpen"]

    if failures.any?
      log = session.evaluate_script("window.__mgateLog")
      abort "Morph state gate FAILED:\n  #{failures.join("\n  ")}\n  after: #{after.inspect}\n  " \
            "final: #{final.inspect}\n  log: #{log.inspect}"
    end

    puts "Morph state gate: the client's tab, value, disclosure and modal dialog survive a Turbo morph; " \
         "the server's change lands; the dialog closes on its own submit"
  end
end
