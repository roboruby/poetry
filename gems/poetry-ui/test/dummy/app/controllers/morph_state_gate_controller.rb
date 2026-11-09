# frozen_string_literal: true

# The morph state gate (rake test:morph_state): a keyed page under a Turbo
# morphing refresh whose state the client changes - a tab, a typed value,
# a disclosure, a modal dialog with a form - across two refresh paths: the
# dialog's form posting and redirecting back (the optimistic-forms shape),
# and a stream-style refresh. The details cookie is the change the server
# makes on purpose, which the morph guard must let through.
class MorphStateGateController < ApplicationController
  layout "stable_id_gate"

  def index
    @details = cookies[:details] == "1"
  end

  def save
    cookies[:details] = params[:details].presence || "1"
    redirect_to "/mgate", status: :see_other
  end
end
