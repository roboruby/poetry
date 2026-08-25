# frozen_string_literal: true

class ApiController < ApplicationController
  include MarkdownMirror

  def index
    @pages = DocsCatalog.apis
  end

  def show
    @slug = params[:slug]
    @meta = ApiReference.meta(@slug)
    raise ActionController::RoutingError, "unknown api page #{@slug}" unless @meta && ApiReference.slugs.include?(@slug)

    @entry = DocsCatalog.find("api", @slug)
    @objects = ApiReference.page_objects(@slug)
  end

  private

  # The .md mirror: the docstrings are markdown already - project the same
  # object list the HTML page renders.
  def markdown_mirror
    slug = params[:slug]
    return api_index_markdown unless slug

    meta = ApiReference.meta(slug)
    raise ActionController::RoutingError, "unknown api page #{slug}" unless meta && ApiReference.slugs.include?(slug)

    ApiReference.page_objects(slug).map { |object| object_markdown(object) }
                .unshift("# #{meta['title']} API\n\n#{meta['description']}").join("\n\n")
  end

  def api_index_markdown
    lines = DocsCatalog.apis.map { |entry| "- [#{entry.title}](#{entry.path}.md) - #{entry.description}" }
    "# API Reference\n\n#{lines.join("\n")}"
  end

  def object_markdown(object)
    parts = [ "## #{object['path']}" ]
    parts << object["docstring"] if object["docstring"].present?
    object["methods"].each do |m|
      sig = m["scope"] == "class" ? ".#{m['signature']}" : "##{m['signature']}"
      parts << "### #{sig}\n\n#{m['docstring']}".rstrip
    end
    parts.join("\n\n")
  end
end
