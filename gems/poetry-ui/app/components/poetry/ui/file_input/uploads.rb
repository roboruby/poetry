# frozen_string_literal: true

module Poetry
  module Ui
    module FileInput
      # What a component that takes files through the file-drop and
      # file-input controllers hands them: the translated rejection and
      # upload messages, the direct uploads endpoint and the upload mode.
      # FileInput's dropzone and the Composer's attachments share it. The
      # including component declares what it reads: the options
      # direct_upload, direct_upload_url and upload, and the constants
      # REJECTION_CODES and UPLOAD_MESSAGES.
      #
      # @api private
      module Uploads
        private

        # The rejection messages by code, translated, as the JSON the
        # file-drop controller reads; the {name}, {size}, {count} and
        # {reason} tokens are the controller's to fill.
        def rejection_messages
          self.class::REJECTION_CODES.to_h { |key, code| [code, t("poetry.file_input.rejected.#{key}")] }.to_json
        end

        # The upload messages, translated, as the JSON the file-input
        # controller reads.
        def upload_messages
          self.class::UPLOAD_MESSAGES.to_h { |key| [key, t("poetry.file_input.upload.#{key}")] }.to_json
        end

        # The direct uploads endpoint: the explicit one, else Rails' own
        # when direct_upload: is on, else nil (no direct uploads).
        def upload_url
          return @upload_url if defined?(@upload_url)

          @upload_url = if direct_upload_url.present?
                          direct_upload_url
                        elsif direct_upload
                          rails_direct_uploads_url
                        end
        end

        # Rails' direct uploads route, or a clear error when the host has
        # not drawn it.
        def rails_direct_uploads_url
          unless helpers.respond_to?(:rails_direct_uploads_url)
            raise ArgumentError, "#{uploads_owner} direct_upload: true needs Active Storage's direct uploads route " \
                                 "(config.active_storage.draw_direct_upload_route) - or pass direct_upload_url:"
          end

          helpers.rails_direct_uploads_url
        end

        # The controller's upload mode: none without an endpoint, else the
        # upload: option.
        def upload_mode
          upload_url ? upload.to_s : "none"
        end

        # The including component's name, for error messages (FileInput, Composer).
        def uploads_owner
          self.class.name.to_s.split("::")[-2]
        end
      end
    end
  end
end
