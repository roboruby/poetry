# frozen_string_literal: true

module Poetry
  module Ui
    # One Active Storage attachment as the Attachment chip shows it: the
    # blob's analyze and variant lifecycle read as the chip's states.
    #
    # - `processing` until the blob is analyzed, and until the requested
    #   variant or preview is processed where Active Storage can say so
    #   (`processed?`, public from Rails 8.2; earlier Rails processes lazily
    #   on request and the image renders straight away);
    # - `error` when an image blob finished analysis with no dimensions,
    #   which is what an unprocessable file leaves behind, with a cell
    #   (Hot Cell's permanent failure records an empty analysis and never
    #   retries) and without one;
    # - `done` otherwise, with the representation as the media when there
    #   is one, else an icon by content type.
    #
    # Only public Active Storage API is read, through duck typing: an
    # `ActiveStorage::Attached::One`, an `ActiveStorage::Attachment` or a
    # bare `ActiveStorage::Blob` all resolve. Nothing here processes a
    # byte; the representation URL does, in the app or in the cell.
    class AttachmentLifecycle
      # Content types that read as archives.
      ARCHIVE_TYPES = %w[application/zip application/x-zip-compressed application/x-7z-compressed application/x-tar
                         application/gzip application/x-gzip application/x-rar-compressed application/vnd.rar].freeze

      attr_reader :attachment, :blob, :variant

      # @param given [Object] an Attached::One, an Attachment or a Blob
      # @param variant [Symbol, Hash, nil] the named variant or transformations to show as the media
      def initialize(given, variant: nil)
        @attachment, @blob = resolve(given)
        @variant = variant
      end

      # Whether there is a blob to show.
      def present?
        !blob.nil?
      end

      # The chip's state for this moment of the lifecycle.
      # @return [Symbol] :processing, :error or :done
      def state
        return :error if unprocessable?
        return :processing if pending_analysis? || pending_representation?

        :done
      end

      # The file name, user content.
      def filename
        blob.filename.to_s
      end

      # The blob's content type, or an empty string.
      def content_type
        blob.respond_to?(:content_type) ? blob.content_type.to_s : ""
      end

      # Whether the blob is an image.
      def image?
        blob.respond_to?(:image?) ? blob.image? : content_type.start_with?("image/")
      end

      # Whether analysis is still to come (the analyze job, in the app or
      # the cell, has not written metadata yet).
      def pending_analysis?
        blob.respond_to?(:analyzed?) && !blob.analyzed?
      end

      # An image analyzed without dimensions by an analyzer that takes
      # images: the file could not be read, or the permanent failure Hot
      # Cell records and never retries. An app with no image analyzer
      # configured never analyzes dimensions, so its images are done.
      def unprocessable?
        return false unless image? && !pending_analysis? && blob.respond_to?(:metadata) && analyzer_accepts?

        metadata = blob.metadata || {}
        metadata["width"].blank? && metadata[:width].blank?
      end

      # Whether a configured analyzer takes this blob; true outside Active
      # Storage, where a stand-in's metadata is the whole story.
      def analyzer_accepts?
        return true unless defined?(::ActiveStorage) && ::ActiveStorage.respond_to?(:analyzers)

        ::ActiveStorage.analyzers.any? { |analyzer| analyzer.accept?(blob) }
      end

      # Whether a variant was asked for and the blob can represent it.
      def representable?
        return false if variant.blank?

        blob.respond_to?(:representable?) ? blob.representable? : image?
      end

      # The representation (variant or preview) of the requested variant.
      def representation
        @representation ||= (attachment || blob).representation(variant)
      end

      # Whether the representation is still to be processed, where Active
      # Storage can say (`processed?`); a lazily processed one is never
      # pending here, its URL does the work.
      def pending_representation?
        return false unless representable?

        representation.respond_to?(:processed?) && !representation.processed?
      end

      # Whether the media is the representation itself: representable,
      # processed, and the blob in a state to show it.
      def image_ready?
        representable? && !pending_representation? && !unprocessable? && !pending_analysis?
      end

      # The Lucide icon for the content type family.
      # @return [Symbol]
      def icon
        type = content_type
        return :image if image?
        return :film if type.start_with?("video/")
        return :music if type.start_with?("audio/")
        return :"file-archive" if ARCHIVE_TYPES.include?(type)
        return :"file-text" if type == "application/pdf" || type.start_with?("text/")

        :file
      end

      # The metadata line: the size and the file type, or what went wrong.
      #
      # @param view [ActionView::Base] for number_to_human_size and the translations
      # @return [String]
      def description(view)
        return view.t("poetry.attachment.unprocessable") if state == :error

        parts = []
        parts << view.number_to_human_size(blob.byte_size) if blob.respond_to?(:byte_size) && blob.byte_size
        extension = File.extname(filename).delete_prefix(".")
        parts << extension.upcase if extension.present?
        parts.join(" · ")
      end

      # The chip's DOM id, the one the broadcasts replace.
      # @return [String, nil]
      def dom_id
        if attachment.respond_to?(:id) && attachment.id
          "poetry_attachment_#{attachment.id}"
        elsif blob.respond_to?(:id) && blob.id
          "poetry_blob_#{blob.id}"
        end
      end

      # The download URL, as an attachment disposition.
      #
      # @param view [ActionView::Base] with Active Storage's route helpers
      # @return [String, nil]
      def download_path(view)
        return unless view.respond_to?(:rails_blob_path)

        view.rails_blob_path(blob, disposition: "attachment")
      end

      private

      # The attachment and the blob behind what was given: an Attached::One
      # (its attachment, nil when nothing is attached), an Attachment (and
      # its blob), or a bare Blob.
      def resolve(given)
        given = given.attachment if given.respond_to?(:attached?) && given.respond_to?(:attachment)
        return [nil, nil] if given.nil?
        return [given, given.blob] if given.respond_to?(:blob)

        [nil, given]
      end
    end
  end
end
