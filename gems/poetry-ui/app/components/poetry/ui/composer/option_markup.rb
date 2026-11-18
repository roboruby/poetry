# frozen_string_literal: true

module Poetry
  module Ui
    module Composer
      # One menu option's element, the same on the page and in a server's
      # answer: the composer renders it inside each menu's listbox, and
      # MenuOptions renders it inside the frame a server-fed menu asks
      # for. Its id counts positions under the listbox's id, which is what
      # the field's aria-activedescendant names.
      #
      # @api private
      module OptionMarkup
        private

        # One option: its icon, its name and the muted text beside it.
        def menu_option_tag(item, list_id, position)
          parts = []
          parts << render(Icon::Component.new(name: item.icon)) if item.icon
          parts << content_tag(:span, item.label, "data-slot" => "composer-menu-option-label",
                                                  "class" => Style.css(:menu_option_label))
          if item.description.present?
            parts << content_tag(:span, item.description, "data-slot" => "composer-menu-option-description",
                                                          "class" => Style.css(:menu_option_description))
          end
          content_tag(:div, safe_join(parts), **menu_option_attributes(item, list_id, position))
        end

        # One option's attributes: its id for aria-activedescendant, what
        # filtering matches, and what a choice writes.
        def menu_option_attributes(item, list_id, position)
          attrs = {
            "data-slot" => "composer-menu-option", "role" => "option",
            "id" => "#{list_id}-option-#{position}", "aria-selected" => "false",
            "class" => classnames(Command::Style.css(:item), Style.css(:menu_option)),
            "data-value" => item.value, "data-label" => item.label, "data-filter-value" => item.label,
            "data-keywords" => [item.value, *item.keywords].join(" ")
          }
          attrs["data-insert"] = item.insert if item.insert
          attrs["data-run"] = "" if item.run
          attrs
        end
      end
    end
  end
end
