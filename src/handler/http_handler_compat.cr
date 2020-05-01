# Compatibility layer to create `Gripen::Handler` handlers based on existing `HTTP::Handler` handlers.
#
#
module Gripen::Handler::HTTPHandlerCompat(H)
  getter http_handler : HTTP::Handler

  def initialize(*args)
    @http_handler = H.new *args
    @http_handler.next = ->(_context : HTTP::Server::Context) {}
  end
end
