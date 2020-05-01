require "http/web_socket"
require "./action"

# Including this module to a `Controller` adds WebSocket support.
module Gripen::Controller::WebSocket
  # :nodoc:
  struct Action(R)
    include Controller::Action

    struct InvalidHeader
      include Response

      class_getter response_info = Response::Info.new "Invalid header value", http_status: ::HTTP::Status::BAD_REQUEST

      def initialize(header : String, value : String)
        @error_message = "#{@@response_info.description} for #{header}: #{value}"
      end

      def add_response(context : ::HTTP::Server::Context)
        context.response.puts @error_message
      end
    end

    struct MissingHeader
      include Response

      class_getter response_info = Response::Info.new "Missing header", http_status: ::HTTP::Status::BAD_REQUEST

      def initialize(header : String)
        @error_message = "#{@@response_info.description}: #{header}"
      end

      def add_response(context : ::HTTP::Server::Context)
        context.response.puts @error_message
      end
    end

    def initialize(@controller_metadata : Metadata, @proc : Proc(::HTTP::WebSocket, Parameters, ::HTTP::Server::Context, R))
    end

    def call(parameters : Parameters, context : ::HTTP::Server::Context)
      result = nil
      ex = hanle_websocket context do |ws|
        result = @proc.call ws, parameters, context
      end
      ex || result
    end

    private def hanle_websocket(context : ::HTTP::Server::Context, & : ::HTTP::WebSocket ->) : Response?
      return MissingHeader.new("Upgrade") unless upgrade = context.request.headers["Upgrade"]?
      return InvalidHeader.new("Upgrade", upgrade) unless upgrade.compare("websocket", case_insensitive: true) == 0

      if context.request.headers.includes_word?("Connection", "Upgrade")
        response = context.response

        version = context.request.headers["Sec-WebSocket-Version"]?
        unless version == ::HTTP::WebSocket::Protocol::VERSION
          response.status = :upgrade_required
          response.headers["Sec-WebSocket-Version"] = ::HTTP::WebSocket::Protocol::VERSION
          return InvalidHeader.new "Sec-WebSocket-Version", "expected #{::HTTP::WebSocket::Protocol::VERSION}, got #{version}"
        end

        unless key = context.request.headers["Sec-WebSocket-Key"]?
          return MissingHeader.new "Sec-WebSocket-Key"
        end

        accept_code = ::HTTP::WebSocket::Protocol.key_challenge(key)

        response.status = :switching_protocols
        response.headers["Upgrade"] = "websocket"
        response.headers["Connection"] = "Upgrade"
        response.headers["Sec-WebSocket-Accept"] = accept_code
        response.upgrade do |io|
          ws_session = ::HTTP::WebSocket.new(io, sync_close: false)
          yield ws_session
          ws_session.run
        ensure
          io.close
        end
      end
      nil
    end
  end

  # Adds a WebSocket route.
  #
  # Websocket connections are upgraded from a `GET` request, therefore websocket routes will confilct with exising get routes.
  def websocket(
    *path,
    query_params : Array(Parameters::Query.class | String | Symbol)? = nil,
    summary : String? = nil,
    description : String? = nil,
    &action : ::HTTP::WebSocket, Parameters, ::HTTP::Server::Context -> R
  ) forall R
    add_route(
      "GET",
      path,
      Action(R).new(@metadata, action),
      query_params,
      summary,
      description,
    )
  end
end
