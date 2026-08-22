# The blocks gallery (Blocks v1): one page per vetted composed screen.
# The preview renders the REAL gem template inline; the code tab shows the
# exact source `describe_block` returns and `poetry:block` copies in - the
# shadcn model one altitude up: what you see is exactly what you'd own.
class BlocksController < ApplicationController
  include MarkdownMirror

  def show
    @entry = DocsCatalog.find("blocks", params[:slug])
    raise ActionController::RoutingError, "unknown block #{params[:slug]}" unless @entry

    meta = DocsCatalog.block_meta(@entry.slug)
    @components = meta.fetch("components")
    @source = DocsMarkdown.block_source(meta)
    render template: "docs/block_page"
  end

  private

  def markdown_mirror
    entry = DocsCatalog.find("blocks", params[:slug])
    raise ActionController::RoutingError, "unknown block #{params[:slug]}" unless entry

    DocsMarkdown.block(entry)
  end
end
