# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Poetry
  module Core
    # Fetches and validates registry items for the add generator.
    # Security posture - the registry ecosystem's standard defenses plus
    # poetry's tightenings: https only (plain http allowed for localhost work), a
    # response size cap, a redirect limit, env-only auth (${VAR}
    # placeholders expanded from ENV at fetch time, so secrets never live in
    # config files), schema validation before anything downstream touches an
    # item, and NEVER any script execution. Namespaces resolve from the
    # registries: section of config/poetry_components.yml first, then from
    # the public registries.json directory when one is configured.
    #
    # @api private
    class RegistryClient
      class Error < Poetry::Core::Error; end

      MAX_BYTES = 1_048_576
      MAX_REDIRECTS = 3
      LOCAL_HOSTS = %w[localhost 127.0.0.1 ::1 [::1]].freeze
      NAME_FORMAT = /\A[a-z0-9][a-z0-9._-]*\z/

      # @param registries [Hash] "@ns" => a url template String containing
      #   "{name}", or {"url" => template, "headers" => {header => value}}
      # @param directory [String, nil] a registries.json URL for resolving
      #   namespaces that are not configured locally
      # @param base_dir [String] :file addresses resolve relative to this
      # @param fetcher [#call, nil] injectable transport (url, headers) ->
      #   body String; defaults to the hardened Net::HTTP transport
      def initialize(registries: {}, directory: nil, base_dir: Dir.pwd, fetcher: nil)
        @registries = registries || {}
        @directory = directory
        @base_dir = base_dir
        @fetcher = fetcher || method(:default_fetch)
      end

      # Resolve a remote address (:url / :file / :namespace) to a validated
      # item hash.
      def resolve(address)
        payload =
          case address.kind
          when :url then fetch_json(address.location)
          when :file then read_json(address.location)
          when :namespace then fetch_json(*namespace_request(address))
          else raise Error, "#{address.raw.inspect} is not a remote address"
          end
        validate_item!(payload, source: address.raw)
      end

      private

      def namespace_request(address)
        entry = @registries[address.namespace] || directory_entry(address.namespace)
        unless entry
          raise Error, "unknown registry namespace #{address.namespace} - add it to the " \
                       "registries: section of config/poetry_components.yml " \
                       "(or configure directory: with a registries.json URL)"
        end

        template, headers = normalize_registry_entry(address.namespace, entry)
        [template.sub("{name}", address.name), expand_env(headers)]
      end

      def normalize_registry_entry(namespace, entry)
        template, headers =
          case entry
          when String then [entry, {}]
          when Hash then [entry["url"], entry["headers"] || {}]
          end
        unless template.is_a?(String) && template.include?("{name}")
          raise Error, "registry #{namespace} needs a url template containing {name}, got #{entry.inspect}"
        end

        [template, headers]
      end

      # The public directory (registries.json): {"registries" => {"@ns" =>
      # template-or-hash}} - fetched once, memoized for the run.
      def directory_entry(namespace)
        return nil unless @directory

        @directory_registries ||= fetch_json(@directory).fetch("registries") do
          raise Error, "#{@directory} is not a registries.json directory (no registries key)"
        end
        @directory_registries[namespace]
      end

      # Secrets are env-only: config carries ${VAR} placeholders, never
      # values. A missing variable fails loudly before any request is made.
      def expand_env(headers)
        headers.to_h do |key, value|
          expanded = value.to_s.gsub(/\$\{([A-Z0-9_]+)\}/) do
            ENV.fetch(Regexp.last_match(1)) do
              raise Error, "header #{key} references ${#{Regexp.last_match(1)}} but it is not set in ENV"
            end
          end
          [key, expanded]
        end
      end

      def fetch_json(url, headers = {})
        validate_scheme!(url)
        parse_json(@fetcher.call(url, headers), source: url)
      end

      def read_json(location)
        path = File.expand_path(location, @base_dir)
        raise Error, "no registry item file at #{path}" unless File.file?(path)
        raise Error, "#{path} exceeds the #{MAX_BYTES}-byte item cap" if File.size(path) > MAX_BYTES

        parse_json(File.read(path), source: location)
      end

      def parse_json(body, source:)
        raise Error, "#{source} exceeds the #{MAX_BYTES}-byte item cap" if body.bytesize > MAX_BYTES

        JSON.parse(body)
      rescue JSON::ParserError => e
        raise Error, "#{source} is not valid JSON: #{e.message}"
      end

      def validate_scheme!(url)
        uri = URI.parse(url)
        return if uri.scheme == "https"
        return if uri.scheme == "http" && LOCAL_HOSTS.include?(uri.host)

        raise Error, "refusing #{url.inspect}: registries must be https (plain http is allowed for localhost only)"
      end

      def default_fetch(url, headers, hops = 0)
        response = perform_get(URI.parse(url), headers)
        case response
        when Net::HTTPRedirection then follow_redirect(url, headers, response, hops)
        when Net::HTTPSuccess
          body = response.body.to_s
          raise Error, "#{url} exceeds the #{MAX_BYTES}-byte item cap" if body.bytesize > MAX_BYTES

          body
        else
          raise Error, "#{url} responded #{response.code}"
        end
      rescue SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, SocketError => e
        raise Error, "could not fetch #{url}: #{e.message}"
      end

      def perform_get(uri, headers)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                            open_timeout: 5, read_timeout: 10) do |http|
          request = Net::HTTP::Get.new(uri)
          headers.each { |key, value| request[key] = value }
          http.request(request)
        end
      end

      def follow_redirect(url, headers, response, hops)
        raise Error, "too many redirects fetching #{url}" if hops >= MAX_REDIRECTS

        target = URI.join(url, response["location"].to_s).to_s
        validate_scheme!(target)
        default_fetch(target, headers, hops + 1)
      end

      def validate_item!(payload, source:)
        raise Error, "#{source} is not a registry item (expected a JSON object)" unless payload.is_a?(Hash)

        validate_identity!(payload, source: source)
        validate_files!(payload, source: source)
        validate_extras!(payload, source: source)
        payload
      end

      def validate_identity!(payload, source:)
        name = payload["name"]
        unless name.is_a?(String) && name.match?(NAME_FORMAT)
          raise Error,
                "#{source}: item name #{name.inspect} is invalid"
        end

        type = payload["type"]
        return if type.is_a?(String) && type.start_with?("registry:")

        raise Error, "#{source}: item type #{type.inspect} is invalid (expected registry:*)"
      end

      def validate_files!(payload, source:)
        files = payload.fetch("files", [])
        raise Error, "#{source}: files must be an array" unless files.is_a?(Array)

        files.each do |file|
          valid = file.is_a?(Hash) &&
                  file["path"].is_a?(String) && !file["path"].empty? &&
                  file["content"].is_a?(String) &&
                  (file["target"].nil? || file["target"].is_a?(String))
          raise Error, "#{source}: malformed files entry #{file.inspect[0, 120]}" unless valid
        end
      end

      def validate_extras!(payload, source:)
        %w[registryDependencies dependencies].each do |key|
          value = payload[key]
          next if value.nil? || (value.is_a?(Array) && value.all?(String))

          raise Error, "#{source}: #{key} must be an array of strings"
        end
        raise Error, "#{source}: css must be a string" unless payload["css"].nil? || payload["css"].is_a?(String)
        return if payload["cssVars"].nil? || payload["cssVars"].is_a?(Hash)

        raise Error, "#{source}: cssVars must be an object"
      end
    end
  end
end
