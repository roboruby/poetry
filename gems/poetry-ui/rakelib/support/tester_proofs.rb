# frozen_string_literal: true

# The shipped interaction testers (lib/poetry/ui/testing) proven against
# poetry's own preview pages: one method per proof, each driving a
# component through the tester consumers will use and raising on any
# outcome the dommy tier pins - if a controller contract drifts, the
# tester (and every consumer test written through it) fails here first.
class PoetryTesterProofs
  # Each proof method with the name its result prints under.
  PROOFS = {
    select_mouse_sequence: "select drives the full mouse sequence",
    select_popup_height: "select popup opens to its list, never the trigger height",
    select_keyboard_sequence: "select drives the keyboard sequence",
    menu_sequence: "menu opens, activates, and closes",
    dialog_keyboard_and_escape: "dialog opens by keyboard, Escape returns focus to the trigger",
    combobox_filter_and_commit: "combobox filters and commits",
    checkbox_toggles_by_keyboard_and_pointer: "checkbox checks by keyboard, unchecks by pointer, reports its value",
    registration_guard_passes: "registration guard finds every poetry controller registered",
    registration_guard_names_the_stray: "registration guard names an unregistered poetry controller"
  }.freeze

  # Proofs driven through the browser session.
  def initialize(session)
    @session = session
  end

  # The select through its mouse sequence: closed at birth, options listed, a pick commits.
  def select_mouse_sequence
    visit("/previews/poetry/ui/select/default")
    select = Poetry::Ui::Testing::Select.new(root_for("select"), session: @session)

    raise "born open" if select.open?
    raise "options missing Apple: #{select.options}" unless select.options.include?("Apple")

    select.select_option("Banana")
    raise "native value #{select.value.inspect}" unless select.value == "banana"
    raise "value text #{select.text.inspect}" unless select.text == "Banana"
  end

  # The open popup sizes to its list. Five ~32px items cannot fit a
  # trigger-height popup (the collapse class, a hard height on the
  # viewport). Goldens never see open popups; this proof does.
  def select_popup_height
    visit("/previews/poetry/ui/select/default")
    select = Poetry::Ui::Testing::Select.new(root_for("select"), session: @session)

    select.open
    popup_height, item_count = @session.evaluate_script(<<~JS)
      [document.querySelector('[data-slot="select-content"][data-open]')?.getBoundingClientRect()?.height || 0,
       document.querySelectorAll('[data-slot="select-item"]').length]
    JS
    raise "popup #{popup_height}px for #{item_count} items - collapsed to trigger height" if popup_height < 100
  end

  # The select through its keyboard sequence.
  def select_keyboard_sequence
    visit("/previews/poetry/ui/select/default")
    select = Poetry::Ui::Testing::Select.new(root_for("select"), session: @session)

    select.select_option("Blueberry", via: :keyboard)
    raise "native value #{select.value.inspect}" unless select.value == "blueberry"
  end

  # The menu lists items, activates one, and settles closed.
  def menu_sequence
    visit("/previews/poetry/ui/dropdown_menu/default")
    menu = Poetry::Ui::Testing::Menu.new(root_for("dropdown_menu"), session: @session)

    raise "items empty" if menu.items.empty?

    menu.choose("Billing")
    menu.close if menu.open? # plain items may or may not auto-close; either way close settles
    raise "still open" if menu.open?
  end

  # The dialog opens from the keyboard and Escape hands focus back to the trigger.
  def dialog_keyboard_and_escape
    visit("/previews/poetry/ui/dialog/default")
    dialog = Poetry::Ui::Testing::Dialog.new(root_for("dialog"), session: @session)

    dialog.open(via: :keyboard)
    raise "not open" unless dialog.open?

    dialog.close
    focused_action = @session.evaluate_script(
      "document.activeElement && document.activeElement.getAttribute('data-action')"
    )
    raise "focus not returned to the trigger" unless focused_action.to_s.include?("#open")
  end

  # The checkbox checks from the keyboard (Space), unchecks from the
  # pointer, and reports what the form would submit either way.
  def checkbox_toggles_by_keyboard_and_pointer
    visit("/previews/poetry/ui/checkbox/default")
    checkbox = Poetry::Ui::Testing::Checkbox.new(root_for("checkbox"), session: @session)

    raise "checked at birth" if checkbox.checked?

    checkbox.check(via: :keyboard)
    raise "not checked after Space" unless checkbox.checked?
    raise "checked value #{checkbox.value.inspect}" unless checkbox.value == "1"

    checkbox.uncheck
    raise "still checked after the press" if checkbox.checked?
    raise "unchecked value #{checkbox.value.inspect}" unless checkbox.value == "0"
  end

  # The combobox filters on typed text and commits the pick to the native value.
  def combobox_filter_and_commit
    visit("/previews/poetry/ui/combobox/default")
    combobox = Poetry::Ui::Testing::Combobox.new(root_for("combobox"), session: @session)

    combobox.filter("re")
    combobox.select_option("Remix")
    raise "native value #{combobox.value.inspect}" unless combobox.value.to_s == "remix"
  end

  # The registration guard finds nothing missing on a healthy page.
  def registration_guard_passes
    visit("/previews/poetry/ui/dialog/default")
    testing = Object.new.extend(Poetry::Ui::Testing)
    missing = testing.poetry_unregistered_controllers(session: @session)
    raise "unregistered on a healthy page: #{missing.inspect}" unless missing.empty?
    raise "assertion did not pass" unless testing.assert_poetry_controllers_registered(session: @session)
  end

  # The registration guard names an injected unregistered poetry controller.
  def registration_guard_names_the_stray
    visit("/previews/poetry/ui/dialog/default")
    @session.execute_script(<<~JS)
      document.body.insertAdjacentHTML("beforeend", '<div data-controller="poetry--core--nope host--fine"></div>')
    JS
    testing = Object.new.extend(Poetry::Ui::Testing)
    missing = testing.poetry_unregistered_controllers(session: @session)
    raise "expected the injected identifier, got #{missing.inspect}" unless missing == ["poetry--core--nope"]

    begin
      testing.assert_poetry_controllers_registered(session: @session)
      raise "assertion passed with an unregistered controller on the page"
    rescue Poetry::Ui::Testing::RegistrationError => e
      raise "message lacks the identifier: #{e.message}" unless e.message.include?("poetry--core--nope")
    end
  end

  private

  # The first rendered root of a component on the page.
  def root_for(component)
    @session.find("[data-component='#{component}']", match: :first)
  end

  # Visits a preview and waits for the network to go idle: data-poetry-ready
  # flips when Stimulus boots, but the compiled stylesheet can still be in
  # flight, and a click aimed at pre-CSS geometry lands outside the settled
  # layout (Cuprite hit-tests the real point).
  def visit(url)
    poetry_ui_visit_preview(@session, url)
    @session.driver.wait_for_network_idle
  end
end
