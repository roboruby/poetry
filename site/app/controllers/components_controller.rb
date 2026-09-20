class ComponentsController < ApplicationController
  include MarkdownMirror

  def show
    @entry = DocsCatalog.find("components", params[:slug])
    raise ActionController::RoutingError, "unknown component #{params[:slug]}" unless @entry

    @examples = helpers.docs_examples_for("components", @entry.slug)
    render template: "docs/page"
  end

  private

  # The markdown mirror (the append-.md contract): the same page
  # address serves the component's registry-derived contract section -
  # what an agent wants from the page, without the chrome. The key lookup
  # inverts DocsCatalog's slug derivation, so nested keys (command/dialog
  # -> command-dialog) mirror too - a plain tr("-", "_") missed them.
  def markdown_mirror
    registry = Poetry::Ui.registry
    path = registry.entries.keys.find do |key|
      key.split("/")[2..].join("-").tr("_", "-") == params[:slug]
    end
    raise ActionController::RoutingError, "unknown component #{params[:slug]}" unless path

    Poetry::Core::SkillText.new(
      registry: registry, families: Poetry::Ui::SKILL_FAMILIES
    ).sections([ path ])
  end
end
