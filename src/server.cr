require "http/server"
require "./controller"
require "./errors"
require "./handler/logger"

# Gripen web server.
#
# ```
# require "gripen"
#
# server = Gripen.new
#
# server.controller.add do
#   get do |context, params|
#     "Hello!"
#   end
# end
#
# server.start
# ```
class Gripen::Server
  # Server logger, used when the server is starting/stopping.
  getter log : ::Log = Log.for("grippen.server")

  # Server listening host.
  property host : String
  # Server listening port.
  property port : Int32
  property reuse_port : Bool

  # Main server controller, providing default handlers.
  getter controller : Controller

  getter server : HTTP::Server

  # Creates a new web server.
  def initialize(
    @controller : Controller,
    @host : String = "127.0.0.1",
    @port : Int32 = 3000,
    @reuse_port : Bool = false
  )
    @server = HTTP::Server.new do |context|
      controller.resolve_route context
    end
    routes
  end

  # Can be overwritten to add routes.
  def routes : Nil
  end

  # Starts `HTTP::Server` listening on the given `#host` and `#port`.
  #
  # Optionnaly, a `OpenSSL::SSL::Context::Server | Bool | Nil` context can be passed.
  def start(tls = nil) : Nil
    {% if flag?(:without_openssl) %}
      @server.bind_tcp(@host, @port, reuse_port: @reuse_port)
    {% else %}
      if tls && tls.is_a? OpenSSL::SSL::Context::Server
        @server.bind_tls(@host, @port, tls, reuse_port: @reuse_port)
      else
        @server.bind_tcp(@host, @port, reuse_port: @reuse_port)
      end
    {% end %}

    # Handle exiting correctly on stop/kill signals
    Signal::INT.trap { stop }
    Signal::TERM.trap { stop }
    @log.info { "Server listening on #{@host}:#{@port}" }
    @server.listen
  end

  # Stops the server.
  def stop : Nil
    if !@server.closed?
      @log.info { "Stopping server... " }
      @server.close
      @log.info { "stopped." }
    else
      @log.info { "Server not started." }
    end
  end

  # Returns an `HTTP::Client`, which can be used for testing puproses.
  def client(tls = false) : HTTP::Client
    HTTP::Client.new @host, @port, tls
  end

  def add(
    controller_type : T.class,
    *prefix,
    route : Handler::Route? = nil,
    final : Handler::Final? = nil
  ) forall T
    controller = T.new *prefix, route: route, final: final
    with controller yield
    @controller << controller
  end

  private def build_middlewares(handlers)
    last = handlers.first
    handlers[1..].each do |handler|
      last << handler
      last = handler
    end
    handlers.first
  end

  def pipeline(handlers : Array(Handler::Route))
    build_middlewares handlers
  end

  def pipeline(handlers : Array(Handler::Final))
    build_middlewares handlers
  end
end
