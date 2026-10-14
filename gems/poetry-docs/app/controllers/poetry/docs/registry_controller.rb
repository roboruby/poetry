# The official registry endpoints - the docs site doubles as the
# registry, exactly like shadcn's:
#
#   /r/registry.json     the index (shadcn registry.json shape)
#   /r/:name.json        one full item, file content embedded
#   /r/community/registry.json   the community items' index
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

        path = community_path("#{name}.json")
        return head :not_found unless path

        render json: path.read
      end

      # The community index, as its build wrote it.
      def community
        path = community_path("registry.json")
        return head :not_found unless path

        render json: path.read
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

      private

      # A file in the community registry's build output, or nil. The name
      # is already constrained by the route; the expanded path is checked
      # to stay inside the directory all the same.
      def community_path(file)
        root = Poetry::Docs.config.community_registry
        return nil unless root

        dir = Pathname(root).expand_path
        path = dir.join(file).expand_path
        path if path.to_s.start_with?("#{dir}/") && path.file?
      end
    end
  end
end
