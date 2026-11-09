# frozen_string_literal: true

module Poetry
  module Docs
    # The prompts the Installation page hands a human whose assistant has
    # no poetry skill or MCP server yet: the cold-start prompt the gem
    # prints (`bin/rails poetry:prompt`, one text, never restated here)
    # and four task prompts that teach the workflow by example - start
    # from what the app has, compose with the helpers, check last. The
    # page and its markdown mirror read this one list.
    module Prompts
      # One task prompt: the title of its code block and the text to paste.
      Entry = Data.define(:title, :text)

      # The task prompts, in the order the page shows them.
      TO_TRY = [
        Entry.new(title: "A settings page", text: <<~TEXT.chomp),
          Add a settings page for the current user. Start from the closest block (the poetry MCP `compose` tool, or `bin/rails g poetry:block --list`), match the layout and spacing of app/views/users/edit.html.erb, and put the form on the Poetry form builder with one `f.input` per attribute. Run `bin/rails poetry:check` as your last step.
        TEXT
        Entry.new(title: "Empty, loading and error states", text: <<~TEXT.chomp),
          Give app/views/orders/index.html.erb its empty, loading and error states with the Poetry components already in this app (Empty, Skeleton, Alert): no new CSS classes, no raw colors, the existing tokens and variants only. Run `bin/rails poetry:check` as your last step.
        TEXT
        Entry.new(title: "Refactor a form onto the builder", text: <<~TEXT.chomp),
          Refactor app/views/users/_form.html.erb onto `form_with(model:, builder: Poetry::Ui::FormBuilder)`: one `f.input` per field in the current order, labels and errors from the model, nothing hand-wired. Keep the submit behavior. Run `bin/rails poetry:check` as your last step.
        TEXT
        Entry.new(title: "Extend a list, keep the markup", text: <<~TEXT.chomp)
          Add a status column and a status filter to the data table in app/views/orders/index.html.erb, following the markup already there. The filter's state lives in the URL, not in JavaScript. Run `bin/rails poetry:check` as your last step.
        TEXT
      ].freeze

      # The cold-start prompt, from the gem that prints it.
      #
      # @return [String]
      def self.cold_start = Poetry::Ui::Prompt.cold_start
    end
  end
end
