# frozen_string_literal: true

module Poetry
  module Ui
    module Testing
      # The Composer interaction contract: write into the field, send by
      # Enter or by the Send button, read the status the server drew
      # (Send is idle, Stop is running), stop, attach files, and choose
      # from a menu by typing its trigger.
      #
      # The server holds the running state, so a test waits on it the
      # way a person would: send, then ask running?(wait:) and idle?(wait:)
      # for the slot your app redraws.
      #
      # @example Sending a message and stopping the reply
      #   composer = poetry_composer("#composer")
      #   composer.write("Summarise this thread").send_message
      #   assert composer.running?(wait: 2)
      #   composer.stop
      #   assert composer.idle?(wait: 2)
      #
      # @example A mention, a file reference and an attachment
      #   composer.choose("@an", "Ana Diaz")          # the field now reads "@ana "
      #   composer.choose("#", "Roadmap.md")          # a chip, and a hidden field
      #   composer.attach(file_fixture("plan.pdf"))
      #   assert_equal ["plan.pdf"], composer.attachments
      class Composer < Tester
        # The field's current text.
        #
        # @return [String]
        def text
          field.value.to_s
        end

        # Whether there is nothing to send: no text and no file (the
        # root's data-empty, which dims the Send button).
        #
        # @return [Boolean]
        def empty?
          !root["data-empty"].nil?
        end

        # What the action slot shows, as the server drew it.
        #
        # @return [Symbol] :idle, :running or :stopping
        def status
          slot = hidden_part("composer-action")
          return :stopping unless slot["data-stopping"].nil?
          return :running unless slot["data-running"].nil?

          :idle
        end

        # Whether a Stop button is in the slot.
        #
        # @param wait [Numeric] seconds to wait for the state before answering
        # @return [Boolean]
        def running?(wait: 0)
          root.has_selector?("[data-slot='composer-action'][data-running]", wait: wait)
        end

        # Whether the Send button is in the slot.
        #
        # @param wait [Numeric] seconds to wait for the state before answering
        # @return [Boolean]
        def idle?(wait: 0)
          root.has_selector?("[data-slot='composer-action']:not([data-running])", wait: wait)
        end

        # Replaces the draft with `text`, typed into the field.
        #
        # @param text [String] the message text
        # @return [Composer] self
        def write(text)
          field.set(text)
          self
        end

        # Sends the message. via: :keyboard focuses the field and presses
        # Enter; :mouse presses the Send button. Whether it goes is the
        # composer's gate and your server's answer: assert on running? or
        # on your transcript.
        #
        # @param via [Symbol] :keyboard presses Enter in the field, :mouse presses Send
        # @return [Composer] self
        def send_message(via: :keyboard)
          case via
          when :mouse
            press(part("composer-send"))
          else
            focus(field)
            keys(:enter)
          end
          self
        end

        # Presses the Stop button. via: :keyboard focuses it and presses
        # Enter. Raises when no reply is running.
        #
        # @param via [Symbol] :mouse presses Stop, :keyboard focuses it and presses Enter
        # @return [Composer] self
        def stop(via: :mouse)
          button = part("composer-stop")
          case via
          when :keyboard
            focus(button)
            keys(:enter)
          else
            press(button)
          end
          self
        end

        # Attaches files through the composer's own file input (the
        # picker itself cannot be driven) and waits for their chips.
        #
        # @param paths [Array<String, Pathname>] the files to attach
        # @return [Composer] self
        def attach(*paths)
          before = attachments.size
          control = hidden_part("composer-attachments-control")
          session.attach_file(control["id"], paths.flatten.map(&:to_s), make_visible: true)
          wait_until("no chip appeared for #{paths.flatten.map { |path| File.basename(path) }.inspect}") do
            attachments.size > before
          end
          self
        end

        # The attached files' names, in order (the chips above the field).
        #
        # @return [Array<String>]
        def attachments
          chip_titles("composer-attachments")
        end

        # Removes an attached file by its name and waits for its chip to go.
        #
        # @param name [String] the file's name, as its chip shows it
        # @return [Composer] self
        def remove_attachment(name)
          remove_chip("composer-attachments", name)
          wait_until("#{name.inspect} is still attached") { attachments.exclude?(name) }
          self
        end

        # Types `typed` at the caret, which opens the menu its trigger
        # belongs to, then chooses the option with that visible name.
        # via: :keyboard moves the highlight with the arrow keys and
        # presses Enter; :mouse presses the option. A menu fed by the
        # server (src:) is waited for: the choice is made from its answer
        # for the whole of `typed`.
        #
        # @param typed [String] the trigger and, if you like, the start of the option ("@an")
        # @param option [String] the option's visible name ("Ana Diaz")
        # @param via [Symbol] :keyboard arrows to the option and presses Enter, :mouse presses it
        # @return [Composer] self
        def choose(typed, option, via: :keyboard)
          focus(field)
          field.send_keys(typed)
          settle_menus
          menu = open_menu
          target = menu.find("[data-slot='composer-menu-option'][data-label='#{option}']")
          case via
          when :mouse then press(target)
          else arrow_to(menu, target)
          end
          root.assert_no_selector("[data-slot='composer-menu'][data-open]")
          self
        end

        # Whether a menu is open over the composer.
        #
        # @param wait [Numeric] seconds to wait for the state before answering
        # @return [Boolean]
        def menu_open?(wait: 0)
          root.has_selector?("[data-slot='composer-menu'][data-open]", wait: wait)
        end

        # The open menu's options, in the order shown. A menu fed by the
        # server is read once its answer has landed.
        #
        # @return [Array<String>] each option's visible name
        def options
          settle_menus
          return [] unless menu_open?

          open_menu.all("[data-slot='composer-menu-option']", minimum: 0).map { |option| option["data-label"] }
        end

        # The references chosen from chip menus, in order (their chips' names).
        #
        # @return [Array<String>]
        def references
          chip_titles("composer-references")
        end

        # Removes a chosen reference by its name and waits for its chip to go.
        #
        # @param name [String] the reference's name, as its chip shows it
        # @return [Composer] self
        def remove_reference(name)
          remove_chip("composer-references", name)
          wait_until("#{name.inspect} is still referenced") { references.exclude?(name) }
          self
        end

        private

        # The message field.
        def field
          part("input-group-control")
        end

        # The menu that is open, waited for.
        def open_menu
          root.find("[data-slot='composer-menu'][data-open]")
        end

        # Waits out a server-fed menu's request: the menu carries
        # data-loading from the first key until the answer for the last
        # one lands, and the options are replaced when it does.
        def settle_menus
          root.assert_no_selector("[data-slot='composer-menu'][data-loading]", visible: :all)
        end

        # Arrows down to the target option, at most once round the list, and presses Enter.
        def arrow_to(menu, target)
          menu.all("[data-slot='composer-menu-option']").size.times do
            break unless target["data-highlighted"].nil?

            keys(:down)
          end
          wait_until("the highlight never reached #{target["data-label"].inspect}") do
            !target["data-highlighted"].nil?
          end
          keys(:enter)
        end

        # The chips' names in one of the rows above the field.
        def chip_titles(slot)
          return [] unless root.has_selector?(slot_selector(slot), visible: :all, wait: 0)

          # minimum: 0, or an empty row is waited on for the whole default time.
          hidden_part(slot).all("[data-slot='attachment-title']", minimum: 0).map(&:text)
        end

        # Presses the remove button of the chip with that name.
        def remove_chip(slot, name)
          chip = part(slot).find("[data-slot='attachment']", text: name, match: :first)
          press(chip.find("[data-slot='attachment-actions'] button:not([hidden])", match: :first))
        end
      end
    end
  end
end
