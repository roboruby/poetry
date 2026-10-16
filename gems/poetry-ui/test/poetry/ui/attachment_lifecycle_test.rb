# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The lifecycle over duck-typed stand-ins for Active Storage's blob,
    # attachment and representation: the dummy host loads no Active
    # Storage, and the lifecycle reads only its public surface.
    class AttachmentLifecycleTest < ActiveSupport::TestCase
      Representation = Struct.new(:processed, keyword_init: true) do
        def processed? = processed
      end
      LazyRepresentation = Struct.new(:name)

      Blob = Struct.new(:id, :filename, :content_type, :byte_size, :analyzed, :metadata, :representable, :rep,
                        keyword_init: true) do
        def analyzed? = analyzed
        def image? = content_type.to_s.start_with?("image/")
        def representable? = representable
        def representation(_variant) = rep
      end

      Attachment = Struct.new(:id, :blob, :name, :record, keyword_init: true) do
        def representation(variant) = blob.representation(variant)
      end

      AttachedOne = Struct.new(:attachment, keyword_init: true) do
        def attached? = !attachment.nil?
      end

      View = Struct.new(:blob_path, keyword_init: true) do
        def t(key) = "t:#{key}"
        def number_to_human_size(bytes) = "#{bytes / 1024} KB"
        def rails_blob_path(_blob, disposition:) = "#{blob_path}?disposition=#{disposition}"
      end

      def image_blob(**overrides)
        Blob.new(id: 7, filename: "photo.png", content_type: "image/png", byte_size: 2048, analyzed: true,
                 metadata: { "width" => 10, "height" => 10 }, representable: true,
                 rep: Representation.new(processed: true), **overrides)
      end

      def test_resolves_an_attached_one_an_attachment_and_a_bare_blob
        blob = image_blob
        attachment = Attachment.new(id: 3, blob: blob, name: :cover)

        assert_equal blob, AttachmentLifecycle.new(AttachedOne.new(attachment: attachment)).blob
        assert_equal attachment, AttachmentLifecycle.new(attachment).attachment
        assert_equal blob, AttachmentLifecycle.new(blob).blob
        assert_nil AttachmentLifecycle.new(blob).attachment
        refute_predicate AttachmentLifecycle.new(AttachedOne.new(attachment: nil)), :present?
        refute_predicate AttachmentLifecycle.new(nil), :present?
      end

      def test_done_with_a_processed_representation
        lifecycle = AttachmentLifecycle.new(image_blob, variant: :thumb)

        assert_equal :done, lifecycle.state
        assert_predicate lifecycle, :image_ready?
        assert_equal "2 KB · PNG", lifecycle.description(View.new)
      end

      def test_processing_until_analyzed_and_until_the_variant_is_processed
        pending = AttachmentLifecycle.new(image_blob(analyzed: false, metadata: {}), variant: :thumb)

        assert_equal :processing, pending.state
        refute_predicate pending, :image_ready?

        unprocessed = AttachmentLifecycle.new(image_blob(rep: Representation.new(processed: false)),
                                              variant: :thumb)

        assert_equal :processing, unprocessed.state
        refute_predicate unprocessed, :image_ready?
      end

      def test_a_lazily_processed_representation_is_never_pending
        lifecycle = AttachmentLifecycle.new(image_blob(rep: LazyRepresentation.new("thumb")),
                                            variant: :thumb)

        assert_equal :done, lifecycle.state
        assert_predicate lifecycle, :image_ready?
      end

      def test_an_image_analyzed_without_dimensions_is_the_error_state
        lifecycle = AttachmentLifecycle.new(image_blob(metadata: { "identified" => true }), variant: :thumb)

        assert_equal :error, lifecycle.state
        refute_predicate lifecycle, :image_ready?
        assert_equal "t:poetry.attachment.unprocessable", lifecycle.description(View.new)
      end

      def test_without_a_variant_an_image_is_done_with_its_icon
        lifecycle = AttachmentLifecycle.new(image_blob)

        assert_equal :done, lifecycle.state
        refute_predicate lifecycle, :image_ready?
        assert_equal :image, lifecycle.icon
      end

      def test_icons_follow_the_content_type_family
        icon = ->(type, name = "f.bin") { AttachmentLifecycle.new(image_blob(content_type: type, filename: name)).icon }

        assert_equal :film, icon.call("video/mp4")
        assert_equal :music, icon.call("audio/mpeg")
        assert_equal :"file-archive", icon.call("application/zip")
        assert_equal :"file-text", icon.call("application/pdf")
        assert_equal :"file-text", icon.call("text/csv")
        assert_equal :file, icon.call("application/octet-stream")
      end

      def test_a_non_image_is_done_whatever_its_metadata
        lifecycle = AttachmentLifecycle.new(image_blob(content_type: "application/pdf", filename: "deck.pdf",
                                                       metadata: {}))

        assert_equal :done, lifecycle.state
        assert_equal "2 KB · PDF", lifecycle.description(View.new)
      end

      def test_dom_id_and_download_path
        attachment = Attachment.new(id: 3, blob: image_blob, name: :cover)

        assert_equal "poetry_attachment_3", AttachmentLifecycle.new(attachment).dom_id
        assert_equal "poetry_blob_7", AttachmentLifecycle.new(image_blob).dom_id
        assert_equal "/blobs/x?disposition=attachment",
                     AttachmentLifecycle.new(attachment).download_path(View.new(blob_path: "/blobs/x"))
        assert_nil AttachmentLifecycle.new(attachment).download_path(Object.new)
      end
    end
  end
end
