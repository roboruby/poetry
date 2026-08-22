# frozen_string_literal: true

# The append-.md contract, completed site-wide: a docs page answers
# its markdown mirror on EITHER signal - the .md suffix (params[:format])
# or an Accept: text/markdown header. Rails negotiates that header into
# request.format = Mime[:md], which previously fell through to the HTML
# `render template:` and 500d (MissingTemplate); a page with no mirror now
# answers 406 instead. Controllers opt in by defining `markdown_mirror`
# (return the page's markdown; raise RoutingError for unknown slugs so
# unknown addresses stay 404s).
module MarkdownMirror
  extend ActiveSupport::Concern

  included do
    before_action :serve_markdown_mirror, if: :markdown_wanted?
  end

  private

  def markdown_wanted?
    request.get? && (params[:format] == "md" || request.format == Mime[:md])
  end

  def serve_markdown_mirror
    text = markdown_mirror
    return head :not_acceptable unless text

    render plain: text, content_type: "text/markdown"
  end

  def markdown_mirror = nil
end
