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
    prepare_pagination_examples if entry.section == "docs" && entry.slug == "pagination"

    @entry = entry
    @partial = "examples/#{entry.section}/#{entry.slug}/#{params[:name]}"
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
