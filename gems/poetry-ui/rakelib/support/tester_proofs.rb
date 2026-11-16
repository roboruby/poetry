# frozen_string_literal: true

require "tmpdir"

# The shipped interaction testers (lib/poetry/ui/testing) proven against
# poetry's own preview pages (and, for what needs Turbo, the dummy host's
# composer menu gate): one method per proof, each driving a
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
    checkbox_reports_what_the_form_submits: "checkbox reports what the form submits: in a field, disabled, " \
                                            "visual-only",
    composer_writes_and_sends: "composer writes its text, reflects emptiness and submits by key and by button",
    composer_reads_the_status: "composer reads idle, running and stopping from the slot, and presses Stop",
    composer_attaches_files: "composer attaches a file, lists it and removes it",
    composer_chooses_from_menus: "composer chooses a mention by keyboard and a reference by pointer",
    composer_chooses_from_a_server_fed_menu: "composer chooses from a menu the server feeds: its answer as it " \
                                             "came, the newest word's, and options the page rendered",
    composer_keeps_the_page_when_a_menus_server_fails: "composer keeps the page and the draft when a menu's " \
                                                       "server answers with an error or without the frame",
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

  # The value is what the form submits: the same answers when the root is
  # an element around the control, nothing from a disabled control (checked
  # or not), nothing from a control with no input behind it.
  def checkbox_reports_what_the_form_submits
    visit("/previews/poetry/ui/checkbox/in_a_field")
    field = Poetry::Ui::Testing::Checkbox.new("[data-slot='field']", session: @session)
    raise "field: checked value #{field.value.inspect}" unless field.value == "1"

    field.uncheck
    raise "field: unchecked value #{field.value.inspect}" unless field.value == "0"

    visit("/previews/poetry/ui/checkbox/disabled_checked")
    locked = Poetry::Ui::Testing::Checkbox.new(root_for("checkbox"), session: @session)
    raise "disabled and checked reads as unchecked" unless locked.checked?
    raise "disabled value #{locked.value.inspect}" unless locked.value.nil?

    visit("/previews/poetry/ui/checkbox/visual_only")
    bare = Poetry::Ui::Testing::Checkbox.new(root_for("checkbox"), session: @session)
    raise "visual-only value #{bare.value.inspect}" unless bare.value.nil?
  end

  # The combobox filters on typed text and commits the pick to the native value.
  def combobox_filter_and_commit
    visit("/previews/poetry/ui/combobox/default")
    combobox = Poetry::Ui::Testing::Combobox.new(root_for("combobox"), session: @session)

    combobox.filter("re")
    combobox.select_option("Remix")
    raise "native value #{combobox.value.inspect}" unless combobox.value.to_s == "remix"
  end

  # The composer takes text, follows it with its emptiness, and both
  # ways of sending reach the message form once each.
  def composer_writes_and_sends
    visit("/previews/poetry/ui/composer/default")
    composer = Poetry::Ui::Testing::Composer.new(root_for("composer"), session: @session)
    raise "empty at birth expected" unless composer.empty? && composer.status == :idle

    composer.write("Hello there")
    raise "text #{composer.text.inspect}" unless composer.text == "Hello there"
    raise "still empty with text" if composer.empty?

    count_composer_submits
    composer.send_message
    composer.send_message(via: :mouse)
    submits = @session.evaluate_script("window.__composerSubmits")
    raise "submits #{submits.inspect}" unless submits == %w[composer-form composer-form]

    composer.write("")
    raise "not empty after clearing" unless composer.empty?
  end

  # The slot's three states read back, and Stop submits its own form.
  def composer_reads_the_status
    visit("/previews/poetry/ui/composer/stopping")
    stopping = Poetry::Ui::Testing::Composer.new(root_for("composer"), session: @session)
    raise "stopping read as #{stopping.status.inspect}" unless stopping.status == :stopping

    visit("/previews/poetry/ui/composer/running")
    composer = Poetry::Ui::Testing::Composer.new(root_for("composer"), session: @session)
    raise "running read as #{composer.status.inspect}" unless composer.status == :running && composer.running?
    raise "idle? while running" if composer.idle?

    count_composer_submits
    composer.stop
    submits = @session.evaluate_script("window.__composerSubmits")
    raise "stop submitted #{submits.inspect}" unless submits == ["composer-running-stop"]
  end

  # A file attached through the composer's input shows as a chip, makes
  # the message sendable, and leaves by its remove button.
  def composer_attaches_files
    visit("/previews/poetry/ui/composer/with_attachments")
    composer = Poetry::Ui::Testing::Composer.new(root_for("composer"), session: @session)

    Dir.mktmpdir("poetry-composer") do |dir|
      file = File.join(dir, "plan.pdf")
      File.binwrite(file, "%PDF-1.4\n%%EOF\n")
      composer.attach(file)
    end
    raise "attachments #{composer.attachments.inspect}" unless composer.attachments == ["plan.pdf"]
    raise "files alone should not be empty" if composer.empty?

    composer.remove_attachment("plan.pdf")
    raise "still attached: #{composer.attachments.inspect}" unless composer.attachments.empty? && composer.empty?
  end

  # A typed trigger opens its menu; the keyboard writes a mention as
  # text, and the pointer adds a reference as a chip.
  def composer_chooses_from_menus
    visit("/previews/poetry/ui/composer/with_menus")
    composer = Poetry::Ui::Testing::Composer.new(root_for("composer"), session: @session)

    composer.choose("@", "Jordan Lee")
    raise "mention text #{composer.text.inspect}" unless composer.text == "@jordan "
    raise "menu left open" if composer.menu_open?

    composer.choose("#", "Roadmap.md", via: :mouse)
    raise "references #{composer.references.inspect}" unless composer.references == ["Roadmap.md"]
    raise "text after a chip #{composer.text.inspect}" unless composer.text == "@jordan "

    composer.remove_reference("Roadmap.md")
    raise "still referenced: #{composer.references.inspect}" unless composer.references.empty?
  end

  # A menu the server feeds, under real Turbo. A match by an address the
  # page never holds proves the answer is shown as it came. The word "r"
  # is answered late: the request for it is dropped when "ro" is asked
  # about, so the list is the newer word's and stays so. Options the page
  # rendered answer the bare trigger with no request.
  def composer_chooses_from_a_server_fed_menu
    visit("/cgate")
    composer = Poetry::Ui::Testing::Composer.new(@session.find("#people-composer"), session: @session)

    composer.choose("@pri", "Priya Shah")
    raise "mention text #{composer.text.inspect}" unless composer.text == "@priya "

    composer.choose("@acme", "Jordan Lee", via: :mouse)
    raise "text after a match by address #{composer.text.inspect}" unless composer.text == "@priya @jordan "

    composer.write("")
    field = @session.find("#people-composer textarea")
    field.send_keys("@r")
    sleep 0.3
    field.send_keys("o")
    newest = composer.options
    raise "the newer word's answer #{newest.inspect}" unless newest == ["Rosa Park", "Rob Lin"]

    sleep 0.8
    raise "a dropped answer landed: #{composer.options.inspect}" unless composer.options == newest

    recent = Poetry::Ui::Testing::Composer.new(@session.find("#recent-composer"), session: @session)
    asked = "performance.getEntriesByType('resource').filter((entry) => entry.name.includes('/cgate/people')).length"
    requests = -> { @session.evaluate_script(asked) }
    before = requests.call
    @session.find("#recent-composer textarea").send_keys("@")
    raise "rendered options #{recent.options.inspect}" unless recent.options == ["Ana Diaz", "Rob Lin"]
    raise "the bare trigger asked the server" unless requests.call == before

    recent.write("")
    recent.choose("@rosa", "Rosa Park")
    raise "a server's person in a menu with rendered options #{recent.text.inspect}" unless recent.text == "@rosa "
  end

  # A menu whose server fails. Left to Turbo, an error page that asks for
  # a full visit (Rails' own, in development) takes the page and the draft
  # with it, and an answer with no frame puts "Content missing" where the
  # options go. Neither happens: the page and the draft stay, the list
  # holds nothing, and no list opens.
  def composer_keeps_the_page_when_a_menus_server_fails
    visit("/cgate")
    composer = Poetry::Ui::Testing::Composer.new(@session.find("#broken-composer"), session: @session)
    field = @session.find("#broken-composer textarea")

    { "@" => "an error answer", "#" => "an answer without the frame" }.each do |trigger, answer|
      composer.write("")
      field.send_keys("#{trigger}ana")
      @session.assert_no_selector("#broken-composer [data-slot='composer-menu'][data-loading]", visible: :all)
      sleep 0.3
      raise "#{answer}: path #{@session.current_path.inspect}" unless @session.current_path == "/cgate"
      raise "#{answer}: draft #{composer.text.inspect}" unless composer.text == "#{trigger}ana"
      raise "#{answer} opened a list" if composer.menu_open?

      written = @session.evaluate_script(
        "Array.from(document.querySelectorAll('#broken-composer [role=listbox]'))" \
        ".map((list) => list.textContent.trim()).join('')"
      )
      raise "#{answer}: Turbo wrote #{written.inspect} into a list" unless written.empty?
    end
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

  # Records each form submission's form id and holds it there, so a
  # preview page (which has no server behind its forms) stays put.
  def count_composer_submits
    @session.execute_script(<<~JS)
      window.__composerSubmits = []
      document.addEventListener("submit", (event) => {
        window.__composerSubmits.push(event.target.id)
        event.preventDefault()
      }, true)
    JS
  end

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
