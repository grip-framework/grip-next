require "http/status"

# Holds possible responses to send to the client.
#
# ```
# require "gripen/response"
#
# struct User
#   include Gripen::Response
#   class_getter response_info = Gripen::Response::Info.new "User created", http_status: :CREATED, content_type: "application/json"
#
#   def add_response(context)
#     context.response << %({"name": "myuser"})
#   end
# end
# ```
module Gripen::Response
  # Information of this response, must be set.
  class_getter response_info : Response::Info = Response::Info.new

  # Message to add additional information on the error logs. Can be the `@@response_info.description` with additional information.
  getter error_message : String?

  # Optional exception cause.
  #
  # Will be logged in error logs if set.
  getter exception_cause : Exception?

  # Holds response's information, defaults to returning `OK`.
  struct Info
    # The content type returned.
    getter content_type : String = "text/plain"
    # Description of what this response does.
    getter description : String = ""
    # The HTTP status that will be sent  o the client.
    getter http_status : HTTP::Status = HTTP::Status::OK

    def initialize(
      description : String? = nil,
      @http_status : HTTP::Status = HTTP::Status::OK,
      @content_type : String = "text/plain"
    )
      @description = description || @http_status.description.as String
    end
  end

  # Adds a response to client.
  #
  # `.response_info.http_status` will be added before this method being called, then the response will be sent after.
  abstract def add_response(context : HTTP::Server::Context)

  protected def send_response(context : HTTP::Server::Context)
    context.response.content_type = @@response_info.content_type
    context.response.status = @@response_info.http_status
    add_response context
  end
end
