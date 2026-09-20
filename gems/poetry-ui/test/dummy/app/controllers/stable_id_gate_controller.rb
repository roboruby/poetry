# frozen_string_literal: true

# The StableId architectural gate (rake test:morph_identity): a keyed
# record collection whose order flips across a Turbo morphing page
# refresh. keyed=1 renders every row's DropdownMenu with key: record;
# keyed=0 leaves them on the random fallback - the before/after pair the
# gate asserts against.
class StableIdGateController < ApplicationController
  layout "stable_id_gate"

  Message = Struct.new(:id, :subject) do
    # dom_id-addressable without ActiveModel: the gate mirrors a real
    # record's identity surface.
    def to_model = self
    def model_name = ActiveModel::Name.new(self.class, nil, "Message")
    def to_key = [id]
    def persisted? = true
  end

  MESSAGES = [
    Message.new(41, "Quarterly report"),
    Message.new(93, "Launch notes"),
    Message.new(7, "Standup summary")
  ].freeze

  def index
    @keyed = params[:keyed] != "0"
    @messages = params[:order] == "desc" ? MESSAGES.reverse : MESSAGES
  end
end
