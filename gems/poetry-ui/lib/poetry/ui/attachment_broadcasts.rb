# frozen_string_literal: true

module Poetry
  module Ui
    # Turbo Stream broadcasts that move an attachment's chip through its
    # lifecycle without a reload: a model opts in per attribute, and the
    # chip is replaced when the attachment is created, when its blob's
    # analysis lands, and when a variant record is written, in the app or
    # in a cell. The page subscribes to the stream and renders the chips
    # with `poetry_attachment_for`, whose DOM ids are the targets.
    #
    #   class Post < ApplicationRecord
    #     include Poetry::Ui::AttachmentBroadcasts
    #     has_many_attached :photos
    #     broadcasts_attachment_updates_for :photos, variant: :thumb
    #   end
    #
    #   <%= turbo_stream_from @post, :attachments %>
    #   <%= poetry_attachments_for @post.photos, variant: :thumb %>
    #
    # The hooks land on Active Storage's models the first time a model opts
    # in, through their load hooks, so a host that never opts in carries
    # none. Broadcasts need turbo-rails; without it they are no-ops.
    module AttachmentBroadcasts
      extend ActiveSupport::Concern

      # One attribute's opt-in: the stream (a callable of the record, else
      # [record, :attachments]) and the variant to show.
      Registration = Struct.new(:stream, :variant, keyword_init: true) do
        # The stream the record's chips broadcast on.
        #
        # @param record [Object] the model instance the attachments belong to
        # @return [Object] what the stream callable returns, else [record, :attachments]
        def stream_for(record)
          stream ? stream.call(record) : [record, :attachments]
        end
      end

      class_methods do
        # Opts the model's attachments into the broadcasts.
        #
        # @param names [Array<Symbol>] the attachment attributes
        # @param to [Proc, nil] the stream for a record; [record, :attachments] by default
        # @param variant [Symbol, Hash, nil] the variant the chips show
        # @return [void]
        def broadcasts_attachment_updates_for(*names, to: nil, variant: nil)
          AttachmentBroadcasts.register(self, names.map(&:to_sym), stream: to, variant: variant)
        end
      end

      class << self
        # The registrations by model name, then attribute name: a model opts
        # its attributes in one call at a time, and each call adds to what
        # the model already has.
        # @return [Hash{String => Hash{Symbol => Registration}}]
        def registrations
          @registrations ||= {}
        end

        # How a chip is rendered for the stream: a callable of the
        # attachment and the variant returning HTML. The default renders
        # `poetry_attachment_for` through the renderer of a controller
        # defined inside the host (it carries the app's route helpers, which
        # a representation's URL needs; ActionController::Base does not); a
        # test swaps it.
        # @return [Proc]
        def renderer
          @renderer ||= lambda do |attachment, variant|
            rendering_controller.renderer.render(
              inline: "<%= poetry_attachment_for(attachment, variant: variant) %>",
              locals: { attachment: attachment, variant: variant }
            )
          end
        end

        attr_writer :renderer

        # The controller whose renderer draws the chips: a controller
        # defined inside the host, once the app is up, so it carries the
        # app's route helpers (a representation's URL needs them) and its
        # view helpers, which ActionController::Base itself does not. Named
        # under this module, so its template prefixes resolve.
        # @return [Class]
        def rendering_controller
          return const_get(:Renderer, false) if const_defined?(:Renderer, false)

          const_set(:Renderer, Class.new(::ActionController::Base))
        end

        # The Turbo Streams channel, or nil without turbo-rails.
        def channel
          Turbo::StreamsChannel if defined?(Turbo::StreamsChannel)
        end

        # Records a model's opt-in and installs the Active Storage hooks once.
        #
        # @param klass [Class] the model
        # @param names [Array<Symbol>] the attachment attributes
        # @param stream [Proc, nil] the stream for a record
        # @param variant [Symbol, Hash, nil] the variant the chips show
        # @return [Registration]
        def register(klass, names, stream: nil, variant: nil)
          install!
          registration = Registration.new(stream: stream, variant: variant)
          names.each { |name| (registrations[klass.name] ||= {})[name.to_sym] = registration }
          registration
        end

        # The registration an attribute of a record falls under, through the
        # record's ancestors.
        #
        # @param record [Object] the model instance whose class, or a superclass, opted the attribute in
        # @param name [Symbol, String] the attachment attribute
        # @return [Registration, nil]
        def registration_for(record, name)
          record.class.ancestors.each do |ancestor|
            registration = ancestor.name && registrations.dig(ancestor.name, name.to_sym)
            return registration if registration
          end
          nil
        end

        # Replaces one attachment's chip on its record's stream, when the
        # record opted that attribute in. A failure to render or send is
        # logged, never raised: the hooks run inside Active Storage's
        # commits and jobs, and a page's chip is never worth a failed
        # analysis.
        #
        # @param attachment [ActiveStorage::Attachment]
        # @param channel [#broadcast_replace_to] the Turbo Streams channel
        # @return [Object, nil] the channel's answer, nil when nothing went out
        def broadcast(attachment, channel: self.channel)
          return unless channel && attachment.respond_to?(:record) && attachment.record

          registration = registration_for(attachment.record, attachment.name)
          return unless registration

          channel.broadcast_replace_to(
            registration.stream_for(attachment.record),
            target: "poetry_attachment_#{attachment.id}",
            html: renderer.call(attachment, registration.variant)
          )
        rescue StandardError => e
          logger&.error("poetry: attachment broadcast for #{attachment.class}##{attachment.id} failed - " \
                        "#{e.class}: #{e.message}")
          nil
        end

        # Where a failed broadcast is reported.
        # @return [Logger, nil]
        def logger
          Rails.logger if defined?(Rails) && Rails.respond_to?(:logger)
        end

        # Replaces the chips of every attachment of a blob (its analysis
        # landed, or a variant was written).
        #
        # @param blob [ActiveStorage::Blob]
        # @param channel [#broadcast_replace_to] the Turbo Streams channel
        # @return [void]
        def broadcast_blob(blob, channel: self.channel)
          return unless blob.respond_to?(:attachments)

          blob.attachments.each { |attachment| broadcast(attachment, channel: channel) }
        end

        # The Active Storage hooks, installed once, when the models load:
        # the attachment's creation (the first chip), the blob's metadata
        # change (analysis), the variant record's creation (a variant).
        # @api private
        # @return [Symbol, nil] :installed when this call installed them, nil when they were
        def install!
          return if @installed

          @installed = true
          ActiveSupport.on_load(:active_storage_attachment) do
            after_create_commit { Poetry::Ui::AttachmentBroadcasts.broadcast(self) }
          end
          ActiveSupport.on_load(:active_storage_blob) do
            after_update_commit(if: -> { saved_change_to_metadata? }) do
              Poetry::Ui::AttachmentBroadcasts.broadcast_blob(self)
            end
          end
          ActiveSupport.on_load(:active_storage_variant_record) do
            after_create_commit { Poetry::Ui::AttachmentBroadcasts.broadcast_blob(blob) }
          end
          :installed
        end

        # Forgets every registration and the installed flag: a test seam.
        # @api private
        def reset!
          @registrations = {}
          @installed = false
          @renderer = nil
        end
      end
    end
  end
end
