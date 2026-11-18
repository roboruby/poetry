# frozen_string_literal: true

# The composer menu gate (rake test:testers): composers whose menus are fed
# by the server, on the one layout that runs real Turbo. /cgate/people
# answers the word a menu asks about with poetry_composer_menu_options,
# matching names and addresses (an address is never on the page, so a
# match by it proves the answer is shown as it came). The word "r" is
# answered late, so a request Turbo drops for a newer one can be told
# from one it kept. /cgate/broken answers the way Rails' exception page
# does in development (an error that asks Turbo for a full page visit) and
# /cgate/missing with a page that holds no frame, which Turbo would answer
# by writing "Content missing" into the list: neither may reach the page.
class ComposerMenuGateController < ApplicationController
  layout "stable_id_gate"

  PEOPLE = [
    { handle: "ana", name: "Ana Diaz", email: "ana@studio.test", team: "Design" },
    { handle: "jordan", name: "Jordan Lee", email: "jordan@acme.test", team: "Engineering" },
    { handle: "priya", name: "Priya Shah", email: "priya@acme.test", team: "Research" },
    { handle: "rosa", name: "Rosa Park", email: "rosa@studio.test", team: "Design" },
    { handle: "rob", name: "Rob Lin", email: "rob@acme.test", team: "Support" }
  ].freeze

  def index; end

  def people
    word = params[:q].to_s.downcase
    sleep 0.6 if word == "r"
    @people = PEOPLE.select { |person| person[:name].downcase.include?(word) || person[:email].include?(word) }
    render layout: false
  end

  # Rails' exception page carries this meta, and Turbo visits a response
  # that does.
  def broken
    page = '<html><head><meta name="turbo-visit-control" content="reload"></head>' \
           "<body><h1>The directory is down</h1></body></html>"

    render html: page.html_safe, status: :internal_server_error
  end

  def missing
    render html: "<p>No frame here.</p>".html_safe
  end
end
