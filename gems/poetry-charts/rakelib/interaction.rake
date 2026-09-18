# frozen_string_literal: true

# The real-browser interaction proof: headless Chrome drives the tooltip
# engine and the interactive doctrine through every demo page
# (rakelib/support/interaction_proofs.rb holds the proofs). Not in the
# default gate - needs Chrome.
namespace :test do
  desc "Prove the tooltip engine and the interactive doctrine in a real browser"
  task interaction: :"browser:assets" do
    require_relative "support/proof"
    require_relative "support/interaction_proofs"

    session = poetry_charts_browser_session
    proof = PoetryProof.new("interaction")
    proofs = PoetryInteractionProofs.new(session)
    PoetryInteractionProofs::PROOFS.each { |method, name| proof.prove(name) { proofs.public_send(method) } }

    proof.report!(proofs.summary)
  end
end
