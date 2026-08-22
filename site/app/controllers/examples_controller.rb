# frozen_string_literal: true

# The standalone example view: one example partial, chrome-free, in its
# own window - the "open standalone" link on every Preview/Code frame.
# Names validate against the same disk roster the gallery renders
# (docs_examples_for), so nothing outside app/views/examples ever
# resolves.
class ExamplesController < ApplicationController
  include ExampleData
  include Pagy::Method

  layout "example"

  def show
    entry = find_entry
    raise ActionController::RoutingError, "unknown example page" unless entry

    names = helpers.docs_examples_for(entry.section, entry.slug)
    raise ActionController::RoutingError, "unknown example" unless names.include?(params[:name])

    prepare_interactive_demo if entry.section == "demos" && entry.slug == "interactive"
    prepare_chat_replay if entry.section == "demos" && entry.slug == "chat-replay"
    prepare_pagination_examples if entry.section == "docs" && entry.slug == "pagination"

    @entry = entry
    @partial = "examples/#{entry.section}/#{entry.slug}/#{params[:name]}"
  end

  # A block standalone is the block at REAL viewport scale - no containment
  # recipes needed (the docs preview constrains fixed-position blocks like
  # app-shell; a window IS the app frame). The stepper's ?step=N links are
  # relative, so they drive the standalone URL directly.
  def block
    entry = DocsCatalog.find("blocks", params[:slug])
    raise ActionController::RoutingError, "unknown block" unless entry

    @entry = entry
    @source = DocsMarkdown.block_source(DocsCatalog.block_meta(entry.slug))
  end

  private

  def find_entry
    if params[:section] == "docs"
      DocsCatalog.docs.find { |entry| entry.slug == params[:slug] }
    else
      DocsCatalog.find(params[:section], params[:slug])
    end
  end
end
