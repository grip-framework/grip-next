require "./http_handler_compat"

# https://crystal-lang.org/api/master/HTTP/CompressHandler.html
class Gripen::Handler::Compress < Gripen::Handler::Route
  include Gripen::Handler::HTTPHandlerCompat(HTTP::CompressHandler)

  # Set compressors, then continue.
  def call(context : HTTP::Server::Context) : Bool
    @http_handler.call context
    true
  end
end
