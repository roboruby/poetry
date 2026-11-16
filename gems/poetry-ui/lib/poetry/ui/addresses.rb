# frozen_string_literal: true

require "uri"

module Poetry
  module Ui
    # The addresses a page may carry when the text they come from is not
    # the host's: a model's reply, a source a tool returned. Markdown, a
    # citation and a sources list all read their links through here.
    #
    # A scheme has to be one of the allowed ones. An address with none is
    # the host's own: a link may be one, since following it is the
    # reader's choice, and an image may not, since loading it is a request
    # to the host with the reader's session, made without asking. A colon
    # before the first slash that is not a scheme, and any control
    # character, refuse the address: browsers do not all read those alike.
    module Addresses
      # The schemes a link may use.
      LINK_SCHEMES = %w[http https mailto tel].freeze
      # The schemes an image may load from.
      IMAGE_SCHEMES = %w[http https].freeze
      # What a link to such an address carries: the text is not the host's.
      REL = "nofollow noopener noreferrer"

      class << self
        # A link's address as the page may carry it, or nil.
        #
        # @param value [Object] the address as written
        # @return [String, nil]
        def link(value)
          allowed(value, LINK_SCHEMES, relative: true)
        end

        # An image's address as the page may load it, or nil.
        #
        # @param value [Object] the address as written
        # @return [String, nil]
        def image(value)
          allowed(value, IMAGE_SCHEMES, relative: false)
        end

        # The site a web address names, without a leading "www.", or nil
        # for any other address.
        #
        # @param value [Object] the address as written
        # @return [String, nil]
        def host(value)
          url = allowed(value, IMAGE_SCHEMES, relative: false) or return
          URI.parse(url).host.to_s.delete_prefix("www.").presence
        rescue URI::InvalidURIError
          nil
        end

        private

        # The address when its scheme is allowed, or when it has none and a relative one will do.
        def allowed(value, schemes, relative:)
          url = value.to_s.strip
          return if url.empty? || url.match?(/[[:cntrl:]]/)

          scheme = url[/\A([a-zA-Z][a-zA-Z0-9+.-]*):/, 1]
          return (url if schemes.include?(scheme.downcase)) if scheme

          url if relative && !url.start_with?("//") && !url[%r{\A[^/?#]*}].include?(":")
        end
      end
    end
  end
end
