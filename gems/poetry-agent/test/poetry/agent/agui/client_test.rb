# frozen_string_literal: true

require "test_helper"
require "socket"

module Poetry
  module Agent
    module AGUI
      # A one-shot HTTP server on a loopback port that records the request
      # and streams a canned SSE body - no test dependency needed.
      class ClientTest < Minitest::Test
        def serve(status: 200, body: "")
          server = TCPServer.new("127.0.0.1", 0)
          port = server.addr[1]
          recorded = {}
          thread = Thread.new do
            socket = server.accept
            request_line = socket.gets
            headers = {}
            while (line = socket.gets) && line != "\r\n"
              name, value = line.split(":", 2)
              headers[name.downcase] = value.strip
            end
            recorded[:line] = request_line
            recorded[:headers] = headers
            recorded[:body] = socket.read(headers["content-length"].to_i)
            socket.write("HTTP/1.1 #{status} OK\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n")
            body.each_char.each_slice(7) { |slice| socket.write(slice.join) }
            socket.close
          end
          [port, recorded, thread]
        ensure
          server&.close if thread.nil?
        end

        def test_posts_the_run_input_and_yields_streamed_events
          body = "data: {\"type\":\"RUN_STARTED\",\"runId\":\"r\"}\n\ndata: {\"type\":\"RUN_FINISHED\"}\n\n"
          port, recorded, thread = serve(body: body)
          seen = []
          parser = Client.new(url: "http://127.0.0.1:#{port}/run", headers: { "Authorization" => "Bearer x" })
                         .run(RunInput.build(thread_id: "t", run_id: "r",
                                             messages: [])) { |event| seen << event["type"] }
          thread.join

          assert_equal %w[RUN_STARTED RUN_FINISHED], seen
          assert_empty parser.errors
          assert_equal "POST /run HTTP/1.1\r\n", recorded[:line]
          assert_equal "text/event-stream", recorded[:headers]["accept"]
          assert_equal "Bearer x", recorded[:headers]["authorization"]
          assert_equal "t", JSON.parse(recorded[:body])["threadId"]
        end

        def test_a_failing_status_raises_with_the_code
          port, _recorded, thread = serve(status: 503, body: "")
          error = assert_raises(Client::Error) do
            Client.new(url: "http://127.0.0.1:#{port}/run").run(RunInput.build(thread_id: "t", messages: [])) { |_e| nil }
          end
          thread.join

          assert_equal 503, error.status
        end
      end
    end
  end
end
