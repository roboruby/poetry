# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The broadcasts over stand-ins: a model that opts in, an attachment
    # on it, a channel that records what it is told. The Active Storage
    # hooks themselves bind through load hooks the dummy host never runs.
    class AttachmentBroadcastsTest < ActiveSupport::TestCase
      class Post
        include Poetry::Ui::AttachmentBroadcasts
      end

      class Album < Post; end

      Attachment = Struct.new(:id, :name, :record, :blob, keyword_init: true)
      Blob = Struct.new(:attachments, keyword_init: true)

      class Channel
        attr_reader :sent

        def initialize
          @sent = []
        end

        def broadcast_replace_to(stream, target:, html:)
          @sent << [stream, target, html]
        end
      end

      setup do
        AttachmentBroadcasts.reset!
        AttachmentBroadcasts.renderer = ->(attachment, variant) { "<div>#{attachment.name}:#{variant}</div>" }
      end

      teardown { AttachmentBroadcasts.reset! }

      def test_a_registered_attribute_broadcasts_a_replace_on_the_record_stream
        Post.broadcasts_attachment_updates_for :photos, :cover, variant: :thumb
        channel = Channel.new
        post = Post.new

        assert AttachmentBroadcasts.broadcast(Attachment.new(id: 9, name: "photos", record: post), channel: channel)
        assert_equal [[[post, :attachments], "poetry_attachment_9", "<div>photos:thumb</div>"]], channel.sent
      end

      def test_an_attribute_not_registered_and_a_record_not_opted_in_broadcast_nothing
        Post.broadcasts_attachment_updates_for :photos
        channel = Channel.new

        refute AttachmentBroadcasts.broadcast(Attachment.new(id: 1, name: "cover", record: Post.new), channel: channel)
        refute AttachmentBroadcasts.broadcast(Attachment.new(id: 2, name: "photos", record: Object.new),
                                              channel: channel)
        refute AttachmentBroadcasts.broadcast(Attachment.new(id: 3, name: "photos", record: Post.new), channel: nil)
        assert_empty channel.sent
      end

      def test_a_custom_stream_and_a_subclass_inherit_the_registration
        Post.broadcasts_attachment_updates_for :photos, to: ->(record) { ["gallery", record.class.name] }
        channel = Channel.new

        assert AttachmentBroadcasts.broadcast(Attachment.new(id: 4, name: :photos, record: Album.new), channel: channel)
        assert_equal ["gallery", "Poetry::Ui::AttachmentBroadcastsTest::Album"], channel.sent.first.first
      end

      # A model opts in one attribute per call: the second call adds to the
      # first (the walk found photos silently dropped by a later documents
      # call), each attribute keeping its own variant.
      def test_later_opt_ins_add_to_a_model_s_registrations
        Post.broadcasts_attachment_updates_for :photos, variant: :thumb
        Post.broadcasts_attachment_updates_for :documents
        channel = Channel.new
        post = Post.new

        assert AttachmentBroadcasts.broadcast(Attachment.new(id: 5, name: "photos", record: post), channel: channel)
        assert AttachmentBroadcasts.broadcast(Attachment.new(id: 6, name: "documents", record: post), channel: channel)
        assert_equal ["<div>photos:thumb</div>", "<div>documents:</div>"], channel.sent.map(&:last)
      end

      def test_a_blob_broadcasts_every_attachment_it_has
        Post.broadcasts_attachment_updates_for :photos
        channel = Channel.new
        post = Post.new
        blob = Blob.new(attachments: [Attachment.new(id: 1, name: "photos", record: post),
                                      Attachment.new(id: 2, name: "photos", record: post)])
        AttachmentBroadcasts.broadcast_blob(blob, channel: channel)

        assert_equal(%w[poetry_attachment_1 poetry_attachment_2], channel.sent.map { |entry| entry[1] })
      end

      # The hooks run inside Active Storage's commits and jobs: a chip that
      # cannot render must not fail an analysis.
      def test_a_failing_render_is_logged_never_raised
        Post.broadcasts_attachment_updates_for :photos
        AttachmentBroadcasts.renderer = ->(*) { raise ArgumentError, "no route" }
        channel = Channel.new

        assert_nil AttachmentBroadcasts.broadcast(Attachment.new(id: 7, name: "photos", record: Post.new),
                                                  channel: channel)
        assert_empty channel.sent
      end

      # The chips render through a controller defined inside the host, so a
      # representation's URL resolves; ActionController::Base has no routes.
      def test_the_rendering_controller_carries_the_app_s_routes
        controller = AttachmentBroadcasts.rendering_controller

        assert_operator controller, :<, ActionController::Base
        assert_includes controller.ancestors, Rails.application.routes.url_helpers
        assert_same controller, AttachmentBroadcasts.rendering_controller
        assert_equal "Poetry::Ui::AttachmentBroadcasts::Renderer", controller.name
      end

      def test_the_hooks_install_once
        Post.broadcasts_attachment_updates_for :photos

        refute AttachmentBroadcasts.install!, "the first opt-in installed the hooks"

        Album.broadcasts_attachment_updates_for :cover

        refute AttachmentBroadcasts.install!
        AttachmentBroadcasts.reset!

        assert AttachmentBroadcasts.install!
      end
    end
  end
end
