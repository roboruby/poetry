# frozen_string_literal: true

module Poetry
  module Eval
    # A bounded worker pool over a list of units: each worker pulls the
    # next unit until the queue runs dry, and the block records under the
    # shared lock so a file written per unit is never torn.
    module Parallel
      module_function

      # Runs the block once per unit, `concurrency` units at a time; the
      # block receives the unit and the lock. An exception in a worker
      # propagates from the join, so the whole run stops.
      def each(units, concurrency:)
        queue = Queue.new
        units.each { |unit| queue << unit }
        lock = Mutex.new
        workers = Array.new([concurrency, units.size].min) do
          Thread.new do
            loop do
              unit = begin
                queue.pop(true)
              rescue ThreadError
                break
              end
              yield unit, lock
            end
          end
        end
        workers.each(&:join)
      end
    end
  end
end
