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
    after_action :advertise_markdown_mirror
    helper_method :markdown_alternate_path
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

  # Where this page's markdown twin lives, or nil. The root's twin is the
  # llms.txt index (there is no routable "/.md").
  def markdown_alternate_path
    return @markdown_alternate_path if defined?(@markdown_alternate_path)

    @markdown_alternate_path =
      begin
        if request.get? && markdown_mirror.present?
          request.path == "/" ? "/llms.txt" : "#{request.path}.md"
        end
      rescue ActionController::RoutingError
        nil
      end
  end

  # Advertise the twin on the HTML response too (the crawler-facing half
  # of the contract: HTTP Link header + the layout's <link> tag).
  def advertise_markdown_mirror
    return unless response.media_type == "text/html" && (path = markdown_alternate_path)

    response.headers["Link"] = [ response.headers["Link"],
                                 %(<#{path}>; rel="alternate"; type="text/markdown") ].compact.join(", ")
  end
end
