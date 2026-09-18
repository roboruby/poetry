# frozen_string_literal: true

# The shipped interaction testers (lib/poetry/ui/testing), PROVEN
# against poetry's own preview pages (rakelib/support/tester_proofs.rb
# holds the proofs). Browser-gated like visual/axe (needs Chrome; not in
# the default gate).

namespace :test do
  desc "Prove the shipped interaction testers (Poetry::Ui::Testing) against the preview pages"
  task testers: :"browser:assets" do
    require "poetry/ui/testing"
    require_relative "support/proof"
    require_relative "support/tester_proofs"

    session = poetry_ui_browser_session
    proof = PoetryProof.new("testers")
    proofs = PoetryTesterProofs.new(session)
    PoetryTesterProofs::PROOFS.each { |method, name| proof.prove(name) { proofs.public_send(method) } }
    session.quit

    proof.report!("testers: all #{proof.proofs.size} proofs hold (the shipped testers match the live contracts)")
  end
end
