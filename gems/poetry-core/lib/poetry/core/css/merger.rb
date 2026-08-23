# frozen_string_literal: true

module Poetry
  module Core
    # Adapted from https://github.com/jefawks3/fox_tail/blob/main/lib/fox_tail/classname_merger.rb
    module CSS
      # Intelligently merges Tailwind CSS class names by resolving conflicts and removing duplicates.
      #
      # This class provides a convenient wrapper around TailwindMerge::Merger to handle the common
      # pattern of merging multiple Tailwind CSS class lists while automatically resolving style
      # conflicts. When multiple classes target the same CSS property, the last one wins.
      #
      # @example Basic usage
      #   merger = Poetry::Core::CSS::Merger.new
      #   merger.merge('text-red-500', 'text-blue-500')
      #   # => 'text-blue-500' (conflict resolved - last one wins)
      #
      # @example Merging arrays of classes
      #   merger.merge(['bg-white', 'p-4'], ['bg-gray-100', 'rounded'])
      #   # => 'p-4 bg-gray-100 rounded' (bg-white replaced by bg-gray-100)
      #
      # @example Handling nil and blank values
      #   merger.merge('p-4', nil, '', 'rounded')
      #   # => 'p-4 rounded' (nil and blank values are filtered out)
      #
      # @example Working with symbols
      #   merger.merge(:rounded, :'text-center')
      #   # => 'rounded text-center' (symbols converted to strings)
      class Merger
        # Bounded FIFO cache over merge results: components render the same
        # class combinations over and over, so tailwind_merge runs once per
        # DISTINCT combo instead of once per render.
        CACHE_LIMIT = 512

        # Initializes a new CSS merger instance.
        #
        # Creates an underlying TailwindMerge::Merger instance that handles the
        # core logic of identifying and resolving Tailwind CSS class conflicts.
        def initialize
          @base_merger = TailwindMerge::Merger.new
          @cache = {}
          @mutex = Mutex.new
        end

        # Merges multiple Tailwind CSS class names, resolving any styling conflicts.
        #
        # This method intelligently combines CSS classes by:
        # 1. Flattening nested arrays into a single list
        # 2. Removing nil and blank values
        # 3. Converting all values to strings (handles symbols, etc.)
        # 4. Resolving Tailwind class conflicts (last value wins)
        # 5. Removing exact duplicates
        #
        # When multiple classes affect the same CSS property (e.g., text-red-500 and
        # text-blue-500), only the last one in the sequence is kept. Non-conflicting
        # classes are preserved.
        #
        # @param classes [Array<String, Symbol, Array, nil>] One or more class names,
        #   arrays of class names, or nil values to merge
        # @return [String, nil] A space-separated string of merged class names, or nil
        #   if the input is empty after normalization
        #
        # @example Simple merge
        #   merge('p-4', 'rounded')
        #   # => 'p-4 rounded'
        #
        # @example Conflict resolution
        #   merge('text-sm', 'text-lg')
        #   # => 'text-lg'
        #
        # @example Array handling
        #   merge(['p-4', 'rounded'], ['bg-white', 'shadow'])
        #   # => 'p-4 rounded bg-white shadow'
        #
        # @example Blank value filtering
        #   merge('p-4', nil, '', 'rounded')
        #   # => 'p-4 rounded'
        #
        # @example Returns nil for empty input
        #   merge(nil, '', [])
        #   # => nil
        def merge(*classes)
          normalized = classes.flatten.compact_blank.map(&:to_s)
          return nil if normalized.empty?

          key = normalized.join(" ")
          @mutex.synchronize do
            if @cache.key?(key)
              @cache[key]
            else
              @cache.shift if @cache.size >= CACHE_LIMIT # Hash keeps insertion order: shift = FIFO eviction
              @cache[key] = @base_merger.merge(key)
            end
          end
        end
      end
    end
  end
end
