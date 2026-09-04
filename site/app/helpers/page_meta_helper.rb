# The head metadata every page carries: one title/description pair, a
# canonical URL, and the Open Graph and Twitter card tags, resolved once
# per request so both layouts render the same partial.
module PageMetaHelper
  SITE_NAME = "poetry"
  SITE_TITLE = "poetry — The AI-Native UI Component Library for Ruby on Rails"
  SITE_DESCRIPTION_SUFFIX = "for Rails, rendered on the server in plain Ruby and ERB. No React, no build step."
  OG_IMAGE = "landing-og.jpg"

  # The site-wide description, with the counts read from the registry.
  def site_description
    "#{DocsCatalog.components.size} components, #{DocsCatalog.charts.size} chart families, and 9 themes " \
      "#{SITE_DESCRIPTION_SUFFIX}"
  end

  # Everything the meta partial renders, as one hash.
  def page_meta
    title = content_for(:title)
    {
      title: title.present? ? "#{title} — #{SITE_NAME}" : SITE_TITLE,
      og_title: title.presence || SITE_TITLE,
      description: content_for(:description).presence || @entry&.description.presence || site_description,
      canonical: canonical_url,
      image: image_url(OG_IMAGE),
      type: title.present? ? "article" : "website"
    }
  end

  # The page's own URL without query string, on the request's host.
  def canonical_url
    "#{request.base_url}#{request.path}"
  end
end
