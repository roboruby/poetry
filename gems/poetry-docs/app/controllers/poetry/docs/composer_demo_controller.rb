# frozen_string_literal: true

# The Composer page's live examples: the server half of the composer's
# contract, with a scripted reply in place of a model. A message answers
# with the reader's row, an empty reply row, the source the reply streams
# through, and the action slot drawn as Stop. The stream writes the reply
# into its row a few words at a time and, when it ends, draws Send. Stop
# removes the source, which ends the stream, and draws Send.
#
# Nothing is stored: the composer's id travels in the address, and every
# render of the slot is stamped with the clock, so the versioned replace
# drops whichever frame arrives late (the stream's last frame and Stop's
# answer can cross). A message's files are read for their names and sizes,
# which the reader's row shows, and are not kept; a request larger than
# the examples' own limits allow is refused before it is read. The values
# a chip menu posted are shown the same way, as the server received them.
#
# A server-fed menu asks `people` about the word being typed. It answers
# from a fixed directory, a handful of rows at most, names that start with
# the word ahead of the rest.
module Poetry
  module Docs
    class ComposerDemoController < ApplicationController
      include ActionController::Live

      # The scripted reply, streamed a few words at a time.
      REPLY = "The composer holds one form that the page never replaces, so the words you type stay " \
              "where they are while this reply arrives. The button beside the field is the one part " \
              "the server redraws: it became Stop when your message was accepted, and it turns back " \
              "into Send when this sentence ends or when you press Stop, whichever comes first."
      # How many words each frame adds, and the pause before it.
      WORDS_PER_FRAME = 2
      FRAME_MS = 220
      # The files one message may carry here, and the request size that
      # leaves room for them (the examples allow three files of 1 MB).
      MAX_FILES = 3
      MAX_REQUEST_BYTES = 4.megabytes
      # The directory a server-fed menu searches, and the most rows one
      # answer holds. The names are invented.
      TEAMS = %w[Design Engineering Research Support Sales Finance Legal Operations].freeze
      DIRECTORY = [
        "Ana Diaz", "Jordan Lee", "Priya Shah", "Sam Okafor", "Mara Voss", "Marco Reyes", "Maya Lindqvist",
        "Malik Osei", "Noor Haddad", "Nina Petrov", "Omar Farouk", "Olivia Brandt", "Pablo Santos",
        "Quinn Abara", "Rosa Park", "Rob Lin", "Robin Vale", "Ravi Menon", "Sara Koenig", "Sofia Ricci",
        "Tariq Aziz", "Tessa Moreau", "Uma Krishnan", "Victor Hale", "Wanjiru Kamau", "Xavier Roche",
        "Yara Nasser", "Yuki Tanaka", "Zoe Albrecht", "Aiko Mori", "Ben Achebe", "Carla Mendes",
        "Dmitri Volkov", "Elena Fuentes", "Farah Qureshi", "Gus Halloran", "Hana Sato", "Idris Bello",
        "Jules Fontaine", "Kemi Adeyemi"
      ].each_with_index.map do |name, index|
        { name: name, handle: name.split.first.downcase, team: TEAMS[index % TEAMS.size] }
      end.freeze
      MAX_PEOPLE = 8

      # POST: a message, with or without files.
      def create
        return head(:content_too_large) if request.content_length.to_i > MAX_REQUEST_BYTES

        text = params[:message].to_s.strip
        files = attached
        return head(:unprocessable_entity) if text.empty? && files.empty?

        files += references

        reply = "#{composer}-reply-#{SecureRandom.hex(4)}"
        render_streams(
          turbo.append(thread, row(id: "#{reply}-question", text: text, align: :end, files: files)),
          turbo.append(thread, row(id: reply, text: nil, version: 0)),
          turbo.append(composer, source_tag(reply)),
          action(:running)
        )
      end

      # GET: the people a server-fed menu shows for the word being typed.
      # A name that starts with the word comes first, then a name or a
      # team that holds it. The page never holds the teams, so a match by
      # one shows the list is the server's answer.
      def people
        word = params[:q].to_s.strip.downcase.first(40)
        leading, rest = DIRECTORY.select { |person| "#{person[:name]} #{person[:team]}".downcase.include?(word) }
                                 .partition { |person| person[:name].downcase.start_with?(word) }
        @people = (leading + rest).first(MAX_PEOPLE)
        render layout: false
      end

      # POST: Stop.
      def stop
        render_streams(
          turbo.remove(source),
          turbo.append(thread, render_to_string(partial: "poetry/docs/composer_demo/stopped",
                                                locals: { id: "#{composer}-stopped-#{SecureRandom.hex(4)}" })),
          action(:idle)
        )
      end

      # GET: the scripted reply as Turbo Streams over SSE.
      def stream
        response.headers["Content-Type"] = "text/event-stream"
        response.headers["X-Accel-Buffering"] = "no"
        response.headers["Last-Modified"] = Time.now.httpdate

        reply = token(params[:reply]) || "#{composer}-reply"
        frames.each_with_index do |text, index|
          pause(FRAME_MS)
          write_stream(turbo.vreplace(reply, row(id: reply, text: text, version: index + 1)))
        end
        # Removing the source is load-bearing: SSE reconnects after the
        # server closes, and a reconnect would replay the reply.
        write_stream(turbo.remove(source) + action(:idle))
      rescue ActionController::Live::ClientDisconnected
        # Stop removed the source and the browser hung up: the reply ends here.
        nil
      ensure
        response.stream.close
      end

      private

      def turbo = Poetry::Agent::AGUI::TurboStream

      # The composer this request belongs to, from the address.
      def composer = @composer ||= token(params[:composer]) || "composer-demo"

      def thread = "#{composer}-thread-messages"

      def source = "#{composer}-source"

      # An id from the address, or nil when it is not one.
      def token(value) = value.to_s[/\A[a-z0-9-]{1,64}\z/]

      def frames
        words = REPLY.split
        (WORDS_PER_FRAME..words.size + WORDS_PER_FRAME - 1).step(WORDS_PER_FRAME).map { |count| words.first(count).join(" ") }
      end

      # The action slot, stamped with the clock for the versioned replace.
      def action(status)
        slot = helpers.poetry_composer_action(id: composer, status: status, version: (Time.now.to_f * 1000).to_i)
        turbo.vreplace("#{composer}-action", slot)
      end

      def row(id:, text:, align: :start, version: nil, files: [])
        render_to_string(partial: "poetry/docs/composer_demo/row",
                         locals: { id: id, text: text, align: align, version: version, files: files })
      end

      # The values a chip menu posted, as the reader's row shows them: name and no size.
      def references
        Array(params[:context]).grep(String).first(MAX_FILES).map { |value| [ value.first(80), nil ] }
      end

      # The message's files as name and size pairs; anything that is not an upload is left out.
      def attached
        Array(params[:attachments]).select { |file| file.respond_to?(:original_filename) }.first(MAX_FILES)
                                   .map { |file| [ file.original_filename.to_s, file.size.to_i ] }
      end

      def source_tag(reply)
        src = composer_demo_reply_path(composer: composer, reply: reply, instant: params[:instant].presence)
        %(<turbo-stream-source id="#{source}" src="#{ERB::Util.html_escape(src)}"></turbo-stream-source>)
      end

      def render_streams(*streams)
        render body: streams.join, content_type: "text/vnd.turbo-stream.html"
      end

      def write_stream(html)
        response.stream.write(turbo.sse(html))
      end

      def pause(milliseconds)
        return if Rails.env.test? || params[:instant].present?

        sleep(milliseconds / 1000.0)
      end
    end
  end
end
