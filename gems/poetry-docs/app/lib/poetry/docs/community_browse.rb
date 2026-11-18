# frozen_string_literal: true

module Poetry
  module Docs
    # The community component browser's state: the items a search and its
    # filters leave, and for each filter the choices there are with how
    # many items each would give. Everything it needs is in the address
    # (`?q=chart&type=block&library=acme`), so a view of the catalog can be
    # shared and works with no script.
    #
    # It reads the items a host's registry directory holds, in memory,
    # which suits a registry of hundreds. A host with a larger catalog
    # answers the same questions from its own store and hands the Community
    # pages an object with these readers: `items`, `count`, `total`,
    # `query`, `narrowed?`, `facets` (of Facet and Option), `choices` (of
    # Choice), `toggled`, `picker`, `sorts`, `sort` and `params_for`.
    #
    # A filter takes one choice, and the library takes several
    # (`?library=acme+beta`): an item passes when it came from any of them.
    # The library is the sidebar's last line and opens a dialog its
    # choices are picked in; the chosen ones show among the filters in
    # force, not in the sidebar.
    #
    # @example
    #   browse = Poetry::Docs::CommunityBrowse.new(CommunityRegistry.items, q: "chart", type: "block")
    #   browse.items.map(&:name)
    #   browse.facets.first.options.map { |option| [ option.label, option.count ] }
    class CommunityBrowse
      # One filter: the parameter it sets, its heading, the choices shown,
      # how many more there are than shown, whether it is open (all its
      # choices shown because the address asks), whether its choices are
      # picked in a dialog (the sidebar then has one line for it, which
      # opens the dialog; `options` are the chosen ones), and whether it
      # sits in the list's heading, beside the order, instead of the
      # sidebar (a host's own, such as how new an item is).
      Facet = Struct.new(:param, :label, :options, :more, :open, :picker, :heading, keyword_init: true)
      # One choice in force: the filter, its value and how it reads.
      Choice = Struct.new(:param, :value, :label, keyword_init: true)
      # One choice of a filter: its value in the address, how it reads,
      # how many items it would give, and whether it is the one chosen.
      Option = Struct.new(:value, :label, :count, :selected, keyword_init: true)

      # The filters, in the order the sidebar shows them: the parameter,
      # the heading, and how an item answers (one value or several).
      FILTERS = {
        "type" => [ "Type", ->(item) { item.kind.downcase } ],
        "javascript" => [ "JavaScript", ->(item) { item.javascript_level } ],
        "trait" => [ "Looks", ->(item) { item.traits } ],
        "needs" => [ "Builds on", ->(item) { item.needs } ],
        "library" => [ "Library", ->(item) { item.library || "poetry" } ]
      }.freeze
      # How a value reads where its own spelling does not.
      LABELS = {
        "library" => { "poetry" => "Made for Poetry" },
        "javascript" => { "none" => "None of its own", "stimulus" => "Stimulus controller", "island" => "Client island" }
      }.freeze
      # The orders a list can take.
      SORTS = { "name" => "Name", "library" => "Library" }.freeze
      # The filters that take several choices at once, picked in a dialog.
      MULTIPLE = %w[library].freeze
      # How many choices a filter shows before "Show all".
      LIMIT = 10

      # The values an address gives a filter that takes several: one text
      # with spaces between them (an address shows them as "+", and no
      # value holds one) or commas, or a list as a form's checkboxes send
      # one.
      # @param raw [String, Array<String>, nil]
      # @return [Array<String>]
      def self.listed(raw)
        Array(raw).flat_map { |part| part.to_s.split(/[\s,]+/) }.compact_blank.uniq
      end

      # The choices of a filter to show: every one when the filter is open
      # or short, else the first LIMIT with the chosen one kept in view.
      # A host's own browser cuts its filters the same way.
      # @param options [Array<Option>] every choice, in order
      # @param open [Boolean] whether the address asks for them all
      # @return [Array<Option>]
      def self.shown(options, open:)
        return options if open || options.size <= LIMIT

        options.first(LIMIT) | options.select(&:selected)
      end

      # @return [String, nil] the search, as typed
      attr_reader :query
      # The choice made in each filter that has one; a list for a filter
      # that takes several.
      # @return [Hash{String => String, Array<String>}]
      attr_reader :chosen
      # @return [String] a key of SORTS
      attr_reader :sort
      # @return [String, nil] the filter whose choices are all shown
      attr_reader :open

      # @param items [Array<CommunityRegistry::Item>] the whole catalog
      # @param params [Hash, ActionController::Parameters] the address's parameters
      def initialize(items, params = {})
        raw = ->(key) { params[key.to_s] || params[key.to_sym] }
        value = ->(key) { raw.call(key).to_s.strip.presence }
        @all = items
        @query = value.call(:q)
        @chosen = FILTERS.keys.filter_map do |param|
          picked = MULTIPLE.include?(param) ? self.class.listed(raw.call(param)).presence : value.call(param)
          [ param, picked ] if picked
        end.to_h
        @sort = SORTS.key?(value.call(:sort)) ? value.call(:sort) : "name"
        @open = value.call(:more) if FILTERS.key?(value.call(:more))
      end

      # The items the search and every filter leave, in the chosen order.
      # @return [Array<CommunityRegistry::Item>]
      def items
        @items ||= sorted(narrowed(chosen))
      end

      # How many items the search and the filters leave.
      # @return [Integer]
      def count = items.size

      # How many items the catalog holds.
      # @return [Integer]
      def total = @all.size

      # Whether a search or a filter is in force.
      # @return [Boolean]
      def narrowed? = query.present? || chosen.any?

      # Each filter with the choices the catalog has for it. A choice's
      # count is what choosing it would give under the search and the
      # other filters, so a count never promises items that are not there.
      # A filter stays while it has a choice to offer, even one, so the
      # sidebar holds still as the list changes; one with none is left
      # out. A long filter shows its first choices, and all of them once
      # the address opens it (`?more=needs`). A filter that takes several
      # is picked in a dialog: its facet holds the chosen ones.
      # @return [Array<Facet>]
      def facets
        @facets ||= FILTERS.keys.filter_map do |param|
          options = options_for(param)
          next if options.empty?

          picker = MULTIPLE.include?(param)
          shown = picker ? options.select(&:selected) : self.class.shown(options, open: open == param)
          Facet.new(param: param, label: FILTERS.fetch(param).first, options: shown, more: options.size - shown.size,
                    open: open == param, picker: picker)
        end
      end

      # Every choice of a filter, for the dialog it is picked in: the
      # chosen ones first, then the rest, each by what it would give. nil
      # for a name that is no filter.
      # @param param [String]
      # @return [Array<Option>, nil]
      def picker(param)
        options_for(param).partition(&:selected).flatten if FILTERS.key?(param.to_s)
      end

      # The choices in force, one for each value: what the chips show.
      # @return [Array<Choice>]
      def choices
        chosen.flat_map do |param, value|
          Array(value).map { |one| Choice.new(param: param, value: one, label: label_for(param, one)) }
        end
      end

      # The address's parameters with one choice turned: taken where it is
      # not in force, let go where it is. A filter that takes several
      # keeps its other choices.
      # @param param [String]
      # @param value [String]
      # @return [Hash{String => String}]
      def toggled(param, value)
        return params_for(param => (chosen[param] == value ? nil : value)) unless MULTIPLE.include?(param)

        held = Array(chosen[param])
        params_for(param => (held.include?(value) ? held - [ value ] : held + [ value ]))
      end

      # The address's parameters with some of them changed: a value sets
      # one, nil takes it away, and a list is written with spaces between
      # its values. What a filter's link, a chip and the search's hidden
      # fields are made of.
      # @param changes [Hash{String, Symbol => String, Array<String>, nil}]
      # @return [Hash{String => String}]
      def params_for(changes = {})
        base = { "q" => query, "sort" => (sort unless sort == "name"), "more" => open }.merge(chosen)
        base.merge(changes.transform_keys(&:to_s))
            .transform_values { |value| value.is_a?(Array) ? value.join(" ").presence : value }.compact
      end

      # How a filter's value reads.
      # @return [String]
      def label_for(param, value)
        return LABELS.dig(param, value) if LABELS.dig(param, value)
        return "@#{value}" if param == "library"

        param == "type" ? value.capitalize : value.tr("-", " ")
      end

      # The orders a list can take, by key.
      # @return [Hash{String => String}]
      def sorts = SORTS

      private

      # Every choice of a filter with what choosing it would give, the
      # most items first. A choice in force that gives nothing stays, to
      # be taken off.
      def options_for(param)
        @options ||= {}
        @options[param] ||= begin
          counts = narrowed(chosen.except(param)).flat_map { |item| values(item, param) }.tally
          Array(chosen[param]).each { |value| counts[value] ||= 0 }
          counts.sort_by { |value, count| [ -count, value ] }.map do |value, count|
            Option.new(value: value, label: label_for(param, value), count: count, selected: Array(chosen[param]).include?(value))
          end
        end
      end

      # The catalog under the search and the given choices: an item passes
      # a filter when it answers the choice, or any of several.
      def narrowed(choices)
        @all.select do |item|
          matches?(item) && choices.all? { |param, value| values(item, param).intersect?(Array(value)) }
        end
      end

      # An item's answers to a filter, as a list.
      def values(item, param) = Array(FILTERS.fetch(param).last.call(item)).compact.map(&:to_s)

      # Every word of the search is somewhere in what the item says of
      # itself: its name, title, description, library, looks and what it
      # builds on.
      def matches?(item)
        return true unless query

        text = [ item.name, item.title, item.description, item.library, *item.traits, *item.needs ].compact.join(" ").downcase
        query.downcase.split.all? { |word| text.include?(word) }
      end

      def sorted(items)
        case sort
        when "library" then items.sort_by { |item| [ item.library || "", item.title.downcase ] }
        else items.sort_by { |item| item.title.downcase }
        end
      end
    end
  end
end
