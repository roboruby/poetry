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
    # `query`, `facets`, `chosen`, `sorts`, `sort` and `params_for`.
    #
    # @example
    #   browse = Poetry::Docs::CommunityBrowse.new(CommunityRegistry.items, q: "chart", type: "block")
    #   browse.items.map(&:name)
    #   browse.facets.first.options.map { |option| [ option.label, option.count ] }
    class CommunityBrowse
      # One filter: the parameter it sets, its heading, and its choices.
      Facet = Struct.new(:param, :label, :options, keyword_init: true)
      # One choice of a filter: its value in the address, how it reads,
      # how many items it would give, and whether it is the one chosen.
      Option = Struct.new(:value, :label, :count, :selected, keyword_init: true)

      # The filters, in the order the sidebar shows them: the parameter,
      # the heading, and how an item answers (one value or several).
      FILTERS = {
        "type" => [ "Type", ->(item) { item.kind.downcase } ],
        "library" => [ "Library", ->(item) { item.library || "poetry" } ],
        "javascript" => [ "JavaScript", ->(item) { item.javascript_level } ],
        "trait" => [ "Looks", ->(item) { item.traits } ],
        "needs" => [ "Builds on", ->(item) { item.needs } ]
      }.freeze
      # How a value reads where its own spelling does not.
      LABELS = {
        "library" => { "poetry" => "Made for Poetry" },
        "javascript" => { "none" => "None of its own", "stimulus" => "Stimulus controller", "island" => "Client island" }
      }.freeze
      # The orders a list can take.
      SORTS = { "name" => "Name", "library" => "Library" }.freeze

      # @return [String, nil] the search, as typed
      attr_reader :query
      # @return [Hash{String => String}] the choice made in each filter that has one
      attr_reader :chosen
      # @return [String] a key of SORTS
      attr_reader :sort

      # @param items [Array<CommunityRegistry::Item>] the whole catalog
      # @param params [Hash, ActionController::Parameters] the address's parameters
      def initialize(items, params = {})
        value = ->(key) { (params[key.to_s] || params[key.to_sym]).to_s.strip.presence }
        @all = items
        @query = value.call(:q)
        @chosen = FILTERS.keys.filter_map { |param| [ param, value.call(param) ] if value.call(param) }.to_h
        @sort = SORTS.key?(value.call(:sort)) ? value.call(:sort) : "name"
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
      # A filter with one choice and none chosen tells nothing and is left
      # out.
      # @return [Array<Facet>]
      def facets
        @facets ||= FILTERS.filter_map do |param, (label, _)|
          counts = narrowed(chosen.except(param)).flat_map { |item| values(item, param) }.tally
          options = counts.sort_by { |value, count| [ -count, value ] }.map do |value, count|
            Option.new(value: value, label: label_for(param, value), count: count, selected: chosen[param] == value)
          end
          Facet.new(param: param, label: label, options: options) if options.size > 1 || chosen.key?(param)
        end
      end

      # The address's parameters with some of them changed: a value sets
      # one, nil takes it away. What a filter's link, a chip and the
      # search's hidden fields are made of.
      # @param changes [Hash{String, Symbol => String, nil}]
      # @return [Hash{String => String}]
      def params_for(changes = {})
        base = { "q" => query, "sort" => (sort unless sort == "name") }.merge(chosen)
        base.merge(changes.transform_keys(&:to_s)).compact
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

      # The catalog under the search and the given choices.
      def narrowed(choices)
        @all.select do |item|
          matches?(item) && choices.all? { |param, value| values(item, param).include?(value) }
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
