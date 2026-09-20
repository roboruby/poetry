# The official registry endpoints - the docs site doubles as the
# registry, exactly like shadcn's:
#
#   /r/registry.json     the index (shadcn registry.json shape)
#   /r/:name.json        one full item, file content embedded
#   /r/registries.json   the public namespace directory - the client's
#                        auto-resolution source for unconfigured @namespaces;
#                        carries the verified field the installer's trust
#                        tier reads (@poetry is verified by construction: the
#                        payloads are generated from CI-gated gem registries)
class RegistryController < ApplicationController
  def index
    render json: {
      "$schema" => "https://ui.shadcn.com/schema/registry.json",
      "name" => "poetry",
      "homepage" => request.base_url,
      "items" => RegistryIndex.summaries
    }
  end

  def show
    item = RegistryIndex.item(params[:name].delete_suffix(".json"))
    return head :not_found unless item

    render json: item
  end

  def directory
    render json: {
      "version" => 1,
      "registries" => {
        "@poetry" => {
          "url" => "#{request.base_url}/r/{name}.json",
          "description" => "The official poetry registry - generated from the gems' committed, CI-verified registries.",
          "verified" => true
        }
      }
    }
  end
end
