# frozen_string_literal: true

module Poetry
  module Ui
    module Composer
      # The composer's menus: lists that open over the field while the
      # word being typed starts with a menu's trigger, built with
      # with_menu and each menu's with_item. The server renders every
      # option; the composer-menu controller filters them as the word
      # grows and puts the chosen one into the message. A menu given src:
      # is fed by the server instead: its listbox is a Turbo frame, the
      # controller asks that address about the word being typed, and the
      # view there answers with poetry_composer_menu_options.
      #
      # @api private
      module Menus
        include OptionMarkup

        # The closed vocabulary for a menu's inserts: (what a choice puts in the message).
        INSERTS = %i[text chip].freeze
        # The closed vocabulary for a menu's at: (where its trigger opens it).
        POSITIONS = %i[word start].freeze
        # What the live region says, by translation key.
        MESSAGES = %i[one other added removed].freeze

        # One option of a menu, as with_item collected it.
        Item = Struct.new(:value, :label, :description, :keywords, :icon, :insert, :run, keyword_init: true)

        # What collects options: a menu on the page and a server's answer
        # alike. The includer holds the items and the icon they default to.
        module ItemBuilder
          # Adds one option.
          #
          # @param value [String, nil] what the server receives: the text after the trigger for a text
          #   menu ("ana" for "@ana"), the hidden field's value for a chip menu. Defaults to the label.
          # @param label [String, nil] the option's visible name, and what filtering matches. Defaults
          #   to the value.
          # @param description [String, nil] muted text beside the label (a role, a path, what a command does)
          # @param keywords [Array<String>, String, nil] extra words the option answers to
          # @param icon [Symbol, nil] the option's leading icon; the menu's icon: by default
          # @param insert [String, nil] the exact text a text menu writes in place of the typed word
          #   ("/summarize "), when it is not the trigger and the value
          # @param run [Boolean] the choice takes the typed word out and is only reported, with the
          #   controller's choose event, for the page to act on at once
          # @return [self]
          def with_item(value: nil, label: nil, description: nil, keywords: nil, icon: nil, insert: nil,
                        run: false)
            raise ArgumentError, "Composer menu item needs value: or label:" if value.blank? && label.blank?

            items << Item.new(value: value.presence || label, label: label.presence || value,
                              description: description, keywords: Array(keywords), icon: icon || self.icon,
                              insert: insert, run: run)
            self
          end
        end

        # One menu, as with_menu collected it, and the builder its block adds options to.
        Menu = Struct.new(:trigger, :label, :inserts, :name, :at, :icon, :src, :param, :items, keyword_init: true) do
          include ItemBuilder
        end

        # Adds a menu that opens over the composer while the word at the
        # caret starts with its trigger. Its block adds the options.
        #
        # @param trigger [String] the character that opens the menu ("@", "/", "#")
        # @param label [String] the list's accessible name ("People", "Commands")
        # @param inserts [Symbol] what a choice puts in the message: :text writes the trigger and the
        #   option's value in place of the typed word ("@ana "); :chip takes the typed word out and adds
        #   a chip above the field with a hidden field under name:
        # @param name [String, nil] the param key a chip menu's values arrive under ("context[]")
        # @param at [Symbol] where the trigger opens the menu: :word at the start of any word, :start
        #   only on the message's first word (commands)
        # @param icon [Symbol, nil] the icon each option leads with, unless it names its own
        # @param src [String, nil] an address that answers with the options for the word being typed
        #   (a view that renders poetry_composer_menu_options). The menu asks it as the word grows and
        #   shows what it answers, in its order; options added here show for the bare trigger until
        #   the word is asked about. Needs Turbo on the page.
        # @param param [String] the query key the typed word arrives under at src: ("q")
        # @yield [menu] the menu, to add options to with with_item
        # @return [self]
        def with_menu(trigger:, label:, inserts: :text, name: nil, at: :word, icon: nil, src: nil, param: "q")
          menu = Menu.new(trigger: trigger.to_s, label: label, inserts: inserts, name: name, at: at, icon: icon,
                          src: src.presence, param: param.to_s, items: [])
          validate_menu!(menu)
          yield menu if block_given?
          menu_models << menu
          self
        end

        private

        # The collected menus.
        def menu_models = (@menu_models ||= [])

        # Whether the composer has a menu: the wiring's condition.
        def menus? = menu_models.any?

        # Whether a menu adds chips, so the chips' row and template render.
        def reference_menus? = menu_models.any? { |menu| menu.inserts == :chip }

        # Refuses a menu the controller could not act on.
        def validate_menu!(menu)
          problem = menu_problem(menu)

          raise ArgumentError, "Composer menu #{problem}" if problem
        end

        # What is wrong with a menu, or nil.
        def menu_problem(menu)
          trigger = menu.trigger

          if trigger.empty? || trigger.match?(/\s/)
            "trigger: #{trigger.inspect} must be one or more characters, no spaces"
          elsif menu_models.any? { |other| other.trigger == trigger }
            "trigger: #{trigger.inspect} is already taken"
          elsif menu.label.blank?
            "label: is the list's accessible name"
          elsif INSERTS.exclude?(menu.inserts)
            "inserts: must be one of #{INSERTS.inspect}"
          elsif POSITIONS.exclude?(menu.at)
            "at: must be one of #{POSITIONS.inspect}"
          elsif menu.inserts == :chip && menu.name.blank?
            "inserts: :chip needs name: (the param key its values post under)"
          elsif menu.src && (menu.param.empty? || menu.param.match?(/\s/))
            "param: #{menu.param.inspect} must name the query key the typed word arrives under"
          end
        end

        # A menu's listbox id, which the field's aria-controls names.
        def menu_list_id(index) = "#{composer_id}-menu-#{index}"

        # The live region's messages, translated, as the JSON the
        # controller reads; the {count} and {label} tokens are its to fill.
        def menu_messages
          MESSAGES.to_h { |key| [key, t("poetry.composer.menu.#{key}")] }.to_json
        end

        # A menu's popup: closed, with what the controller reads to act on a choice.
        def menu_attributes(menu)
          element_attributes(:menu, {
            "data-slot" => "composer-menu", "class" => css(:menu), "hidden" => "",
            "data-closed" => "", "data-trigger" => menu.trigger,
            "data-inserts" => menu.inserts.to_s, "data-at" => menu.at.to_s,
            "data-name" => menu.name, "data-src" => menu.src, "data-param" => (menu.param if menu.src)
          }.compact)
        end

        # A menu's listbox element: a Turbo frame when the server feeds it,
        # so the answer lands in the list itself.
        def menu_list_tag(menu) = menu.src ? "turbo-frame" : :div

        # A menu's listbox: named, and holding options only. A server-fed
        # list that renders options is stamped as answering the bare
        # trigger (data-query=""), so they show before any request.
        def menu_list_attributes(menu, index)
          attrs = { "data-slot" => "composer-menu-list", "role" => "listbox", "id" => menu_list_id(index),
                    "aria-label" => menu.label,
                    "class" => classnames(Command::Style.css(:list), css(:menu_list),
                                          (css(:menu_frame) if menu.src)) }
          attrs["data-query"] = "" if menu.src && menu.items.any?
          attrs
        end

        # The chips' row for chosen references: InputGroup's block-start addon, filled by the controller.
        def references_attributes
          group = InputGroup::Style
          element_attributes(:references, {
                               "data-slot" => "composer-references", "data-align" => "block-start",
                               "class" => group.css(:addon, class: "#{group.css(:addon_block_start)} " \
                                                                   "#{css(:attachments)}")
                             })
        end

        # The reference chip template's attributes.
        def reference_template_attributes
          { "data-slot" => "composer-reference-template" }.merge(stimulus_attributes_for(:reference_template))
        end

        # The reference chip's remove action, as the Attachment action's data.
        def reference_remove_data
          { action: stimulus_attributes_for(:reference_remove)["data-action"] }
        end
      end
    end
  end
end
