# The blocks gallery (Blocks v1): one page per vetted composed screen.
# The preview renders the REAL gem template inline; the code tab shows the
# exact source `describe_block` returns and `poetry:block` copies in - the
# shadcn model one altitude up: what you see is exactly what you'd own.
class BlocksController < ApplicationController
  def show
    @entry = DocsCatalog.find("blocks", params[:slug])
    raise ActionController::RoutingError, "unknown block #{params[:slug]}" unless @entry

    meta = DocsCatalog.block_meta(@entry.slug)
    @components = meta.fetch("components")
    @source = Poetry::Ui.root.join(meta.fetch("template")).read
                        .sub(/\A<%#\s*poetry:block[^%]*%>\n?/, "").strip
    render template: "docs/block_page"
  end
end
