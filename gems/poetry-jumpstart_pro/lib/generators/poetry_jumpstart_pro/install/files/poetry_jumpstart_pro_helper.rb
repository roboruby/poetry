# frozen_string_literal: true

# Installed by `bin/rails g poetry_jumpstart_pro:install` - this file is
# yours: edit freely.
#
# The two adapters the Poetry views lean on: Jumpstart's pagination page
# drawn as poetry_pagination, and Jumpstart's toast icons mapped onto
# Poetry's toast variants.
module PoetryJumpstartProHelper
  # Jumpstart toasts name an icon (alert, notice, success); Poetry toasts
  # carry the intent as a variant, which also picks the icon.
  TOAST_VARIANTS = {
    "alert" => :destructive,
    "notice" => :info,
    "success" => :success
  }.freeze

  # The Poetry pagination for a Jumpstart Pagination::Page, the @page a
  # controller's paginate call sets. Renders nothing at a single page and
  # keeps every other query param, through Jumpstart's pagination_path.
  # Any other keywords (the siblings: and edges: window, attributes for the
  # nav) pass through to poetry_pagination.
  #
  #   <%= poetry_pagination_nav(@page) %>
  #
  # @param page [Pagination::Page] the page object
  def poetry_pagination_nav(page, **)
    return "".html_safe unless page.multiple_pages?

    poetry_pagination(current: page.number, total: page.total_pages,
                      path: ->(number) { pagination_path(page, number) }, **)
  end

  # The Poetry toast variant for a Jumpstart toast's icon_name.
  #
  # @param icon_name [String, Symbol, nil] the toast's icon name
  # @return [Symbol] the Poetry toast variant
  def poetry_toast_variant(icon_name)
    TOAST_VARIANTS.fetch(icon_name.to_s, :default)
  end
end
