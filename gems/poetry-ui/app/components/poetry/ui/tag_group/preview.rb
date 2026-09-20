# frozen_string_literal: true

module Poetry
  module Ui
    module TagGroup
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(label: "Topics") do |group|
            group.with_tag(value: "rails") { "Rails" }
            group.with_tag(value: "hotwire") { "Hotwire" }
            group.with_tag(value: "ruby") { "Ruby" }
          end
        end

        # Form mode: one hidden topics[] input per tag submits; removing a
        # tag removes its input.
        def as_form_value
          render_component(name: "post[topics]", label: "Topics") do |group|
            group.with_tag(value: "news") { "News" }
            group.with_tag(value: "release") { "Release" }
          end
        end

        def with_disabled
          render_component(label: "Filters") do |group|
            group.with_tag(value: "status") { "Status: open" }
            group.with_tag(value: "locked", disabled: true) { "Locked" }
            group.with_tag(value: "assignee") { "Assignee: me" }
          end
        end

        # removable: false - display-only chips keep grid navigation but
        # no removal affordance.
        def without_removal
          render_component(label: "Capabilities") do |group|
            group.with_tag(value: "read", removable: false) { "Read" }
            group.with_tag(value: "write", removable: false) { "Write" }
          end
        end
      end
    end
  end
end
