# frozen_string_literal: true

# The shipped interaction testers (lib/poetry/ui/testing), PROVEN
# against poetry's own preview pages: each proof drives a component through
# a real sequence via the tester consumers will use, and asserts the same
# outcomes the dommy tier pins - if a controller contract drifts, the
# tester (and every consumer test written through it) fails here first.
# Browser-gated like visual/axe (needs Chrome; not in the default gate).

namespace :test do
  desc "Prove the shipped interaction testers (Poetry::Ui::Testing) against the preview pages"
  task testers: :"browser:assets" do
    require "poetry/ui/testing"

    session = poetry_ui_browser_session
    failures = []
    proofs = []

    prove = lambda do |name, &block|
      proofs << name
      block.call
      puts "  testers: #{name} ok"
    rescue StandardError => e
      failures << "#{name}: #{e.class}: #{e.message.lines.first&.strip}"
    end

    root_for = lambda do |component|
      session.find("[data-component='#{component}']", match: :first)
    end

    # data-poetry-ready flips when STIMULUS boots - the compiled stylesheet
    # can still be in flight, and a click aimed at pre-CSS geometry lands
    # outside the settled layout (Cuprite hit-tests the real point). Wait
    # for the network to go idle so coordinates are final.
    visit = lambda do |url|
      poetry_ui_visit_preview(session, url)
      session.driver.wait_for_network_idle
    end

    prove.call("select drives the full mouse sequence") do
      visit.call("/previews/poetry/ui/select/default")
      select = Poetry::Ui::Testing::Select.new(root_for.call("select"), session: session)

      raise "born open" if select.open?
      raise "options missing Apple: #{select.options}" unless select.options.include?("Apple")

      select.select_option("Banana")
      raise "native value #{select.value.inspect}" unless select.value == "banana"
      raise "value text #{select.text.inspect}" unless select.text == "Banana"
    end

    prove.call("select popup opens to its list, never the trigger height") do
      visit.call("/previews/poetry/ui/select/default")
      select = Poetry::Ui::Testing::Select.new(root_for.call("select"), session: session)

      select.open
      popup_height, item_count = session.evaluate_script(<<~JS)
        [document.querySelector('[data-slot="select-content"][data-open]')?.getBoundingClientRect()?.height || 0,
         document.querySelectorAll('[data-slot="select-item"]').length]
      JS
      # Five ~32px items cannot fit a trigger-height popup: the
      # collapse (a hard h-[var(--radix-select-trigger-height)] on the
      # viewport). Goldens never see open popups; this proof does.
      raise "popup #{popup_height}px for #{item_count} items - collapsed to trigger height" if popup_height < 100
    end

    prove.call("select drives the keyboard sequence") do
      visit.call("/previews/poetry/ui/select/default")
      select = Poetry::Ui::Testing::Select.new(root_for.call("select"), session: session)

      select.select_option("Blueberry", via: :keyboard)
      raise "native value #{select.value.inspect}" unless select.value == "blueberry"
    end

    prove.call("menu opens, activates, and closes") do
      visit.call("/previews/poetry/ui/dropdown_menu/default")
      menu = Poetry::Ui::Testing::Menu.new(root_for.call("dropdown_menu"), session: session)

      raise "items empty" if menu.items.empty?

      menu.choose("Billing")
      menu.close if menu.open? # plain items may or may not auto-close; either way close settles
      raise "still open" if menu.open?
    end

    prove.call("dialog opens by keyboard, Escape returns focus to the trigger") do
      visit.call("/previews/poetry/ui/dialog/default")
      dialog = Poetry::Ui::Testing::Dialog.new(root_for.call("dialog"), session: session)

      dialog.open(via: :keyboard)
      raise "not open" unless dialog.open?

      dialog.close
      focused_action = session.evaluate_script(
        "document.activeElement && document.activeElement.getAttribute('data-action')"
      )
      raise "focus not returned to the trigger" unless focused_action.to_s.include?("#open")
    end

    prove.call("combobox filters and commits") do
      visit.call("/previews/poetry/ui/combobox/default")
      combobox = Poetry::Ui::Testing::Combobox.new(root_for.call("combobox"), session: session)

      combobox.filter("re")
      combobox.select_option("Remix")
      raise "native value #{combobox.value.inspect}" unless combobox.value.to_s == "remix"
    end

    session.quit

    abort "testers: #{failures.size}/#{proofs.size} proofs FAILED\n  " + failures.join("\n  ") if failures.any?

    puts "testers: all #{proofs.size} proofs hold (the shipped testers match the live contracts)"
  end
end
