# The official registry endpoints - the docs site doubles as the
# registry, exactly like shadcn's:
#
#   /r/registry.json     the index (shadcn registry.json shape)
#   /r/:name.json        one full item, file content embedded
#   /r/community/registry.json   the community items' index
#   /r/community/screenshots/:name.webp   an item's screenshot, beside the index
#   /r/registries.json   the public namespace directory - the client's
#                        auto-resolution source for unconfigured @namespaces;
#                        carries the verified field the installer's trust
#                        tier reads (@poetry is verified by construction: the
#                        payloads are generated from CI-gated gem registries)
module Poetry
  module Docs
    class RegistryController < ApplicationController
      def index
        render json: {
          "$schema" => "https://ui.shadcn.com/schema/registry.json",
          "name" => "poetry",
          "homepage" => request.base_url,
          "items" => RegistryIndex.summaries
        }
      end

      # An item: the gems' own, else a community item of that name.
      def show
        name = params[:name].delete_suffix(".json")
        item = RegistryIndex.item(name)
        return render json: item if item

        path = CommunityRegistry.file("#{name}.json")
        return head :not_found unless path

        render json: path.read
      end

      # The community index, as its build wrote it.
      def community
        path = CommunityRegistry.file("registry.json")
        return head :not_found unless path

        render json: path.read
      end

      # An item's screenshot, at the address its index entry names
      # relative to the index.
      def screenshot
        path = CommunityRegistry.file("screenshots/#{params[:file]}")
        return head :not_found unless path

        expires_in 1.hour, public: true
        send_file path, type: "image/webp", disposition: "inline"
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
  end
end
