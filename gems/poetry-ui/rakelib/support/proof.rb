# frozen_string_literal: true

# A browser proof run: named steps, each failure recorded rather than
# fatal so one run reports every broken contract, and one verdict at the
# end - an abort naming the failures, or the summary line.
class PoetryProof
  # The step names run so far.
  attr_reader :proofs
  # The failures recorded so far, one line each.
  attr_reader :failures

  # A proof run printing under the label.
  def initialize(label)
    @label = label
    @proofs = []
    @failures = []
  end

  # Runs one named step; an exception becomes a recorded failure.
  def prove(name)
    proofs << name
    yield
    puts "  #{@label}: #{name} ok"
  rescue StandardError => e
    failures << "#{name}: #{e.class}: #{e.message.lines.first&.strip}"
  end

  # Aborts with every failure, or prints the summary when all steps held.
  def report!(summary)
    abort "#{@label}: #{failures.size}/#{proofs.size} proofs FAILED\n  #{failures.join("\n  ")}" if failures.any?

    puts summary
  end
end
