class ComponentsController < ApplicationController
  def show
    # The markdown mirror (the append-.md contract): the same page
    # address with .md serves the component's registry-derived contract
    # section - what an agent wants from the page, without the chrome.
    return markdown if params[:format] == "md"

    @entry = DocsCatalog.find("components", params[:slug])
    raise ActionController::RoutingError, "unknown component #{params[:slug]}" unless @entry

    @examples = helpers.docs_examples_for("components", @entry.slug)
    render template: "docs/page"
  end

  private

  def markdown
    path = "poetry/ui/#{params[:slug].tr('-', '_')}"
    registry = Poetry::Ui.registry
    raise ActionController::RoutingError, "unknown component #{params[:slug]}" unless registry.entries.key?(path)

    sections = Poetry::Core::SkillText.new(
      registry: registry, families: Poetry::Ui::SKILL_FAMILIES
    ).sections([ path ])

    render plain: sections, content_type: "text/markdown"
  end
end
