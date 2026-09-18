# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    # The @api private namespaces read from source, and the prefix contract.
    class ApiInternalsTest < Minitest::Test
      def test_scan_reads_the_tag_off_classes_modules_and_constant_assigned_namespaces
        Dir.mktmpdir do |dir|
          FileUtils.mkdir_p(File.join(dir, "lib/kit"))
          File.write(File.join(dir, "lib/kit/things.rb"), <<~RUBY)
            module Kit
              # A public one.
              class Public; end

              # Kept out of the reference.
              # @api private
              class Hidden
                # Nested under a hidden one: covered by the prefix, never listed.
                # @api private
                class Deeper; end
              end

              # @api private
              module Helpers; end

              # @api private
              Row = Struct.new(:a, :b)

              # Tagged in prose, not as a tag: @api private mentioned here does not count.
              class Mentioned; end
            end
          RUBY

          assert_equal %w[Kit::Helpers Kit::Hidden Kit::Row], ApiInternals.scan(dir)
        end
      end

      def test_scan_finds_the_gems_own_internals_top_most_only
        internals = ApiInternals.scan(Poetry::Core.root)

        assert_includes internals, "Poetry::Core::HostComponents"
        assert_includes internals, "Poetry::Core::Check"
        refute_includes internals, "Poetry::Core::Registry"
        refute_includes internals, "Poetry::Core::Check::Finding"
      end

      def test_internal_matches_a_namespace_exactly_or_beneath_it
        internals = %w[Poetry::Core::Check]

        assert ApiInternals.internal?("Poetry::Core::Check", internals)
        assert ApiInternals.internal?("Poetry::Core::Check::Finding", internals)
        refute ApiInternals.internal?("Poetry::Core::Checker", internals)
        refute ApiInternals.internal?("Poetry::Core::Registry", internals)
      end
    end
  end
end
