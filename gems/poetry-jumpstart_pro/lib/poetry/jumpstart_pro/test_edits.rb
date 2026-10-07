# frozen_string_literal: true

module Poetry
  module JumpstartPro
    # Jumpstart Pro's own tests that assert on markup this gem replaces, and
    # the selector each needs once the Poetry views are in. Poetry's submit
    # is a button named commit rather than an input, and Poetry's pagination
    # is a nav labeled "pagination" whose links carry no rel. Each edit
    # follows the category whose views change the markup.
    #
    # @example The edits for an auth install
    #   Poetry::JumpstartPro::TestEdits.for(%w[auth]).map(&:file)
    #   # => ["test/application_system_test_case.rb", "test/system/login_system_test.rb"]
    module TestEdits
      # One edit: the category it follows, the host test file, the text or
      # pattern to find and its replacement.
      Edit = Data.define(:category, :file, :pattern, :replacement) do
        # Whether the edit still has something to change in a source.
        #
        # @param source [String] the test file's contents
        # @return [Boolean]
        def applies_to?(source)
          pattern.is_a?(Regexp) ? source.match?(pattern) : source.include?(pattern)
        end
      end

      # The input-only commit selector, which a Poetry submit button never matches.
      INPUT_COMMIT = %(find('input[name="commit"]'))
      # The selector both an input and a button named commit match.
      ANY_COMMIT = %(find('[name="commit"]'))

      # Every edit the installer knows.
      EDITS = [
        Edit.new("auth", "test/application_system_test_case.rb", INPUT_COMMIT, ANY_COMMIT),
        Edit.new("auth", "test/system/login_system_test.rb", INPUT_COMMIT, ANY_COMMIT),
        Edit.new("accounts", "test/controllers/concerns/pagination_test.rb",
                 /nav\.pagination a\[rel=(?:next|prev)\]/, "nav[aria-label=pagination] a")
      ].freeze

      module_function

      # The edits for the installed categories.
      #
      # @param categories [Array<String>] the categories being installed
      # @return [Array<Edit>]
      def for(categories)
        EDITS.select { |edit| categories.include?(edit.category) }
      end
    end
  end
end
