require "./action"

# Including this module to a `Controller` adds HTTP support.
#
#
# ```
# require "gripen/controller"
# require "gripen/controller/http"
#
# struct Controller < Gripen::Controller
#   include Gripen::Controller::HTTP
# end
#
# metadata = Gripen::Controller::Metadata.new "Public API"
# controller = Controller.new("api", "public", metadata)
#
# controller << Controller.new.add do
#   get "api" do |params, context|
#   end
#
#   post "api", request_body: String do |body, params, context|
#   end
# end
# ```
module Gripen::Controller::HTTP
  # A request body from a POST, PUT, DELETE or PATCH method. **Must** implement `self.from_io(body: IO)`.
  abstract struct RequestBody
  end

  # Possible request body types a route can accept.
  #
  # `Nil` expects the client to send an empty or no request body.
  alias RequestBodyTypes = RequestBody.class | String.class | IO.class | Nil.class | Int.class | Float.class

  struct MissingRequestBody(T)
    include Response
    class_getter response_info = Response::Info.new "Missing request body", http_status: :BAD_REQUEST
    getter error_message = "#{@@response_info.description}: expecting #{T}"

    def add_response(context : ::HTTP::Server::Context)
      context.response.puts @@response_info.description
    end
  end

  struct UnexpectedRequestBody(T)
    include Response
    class_getter response_info = Response::Info.new "Unexpected request body", http_status: :BAD_REQUEST
    getter error_message = "#{@@response_info.description}: expecting #{T}"

    def add_response(context : ::HTTP::Server::Context)
      context.response.puts @@response_info.description
    end
  end

  # :nodoc:
  struct NoRequestBodyAction(R)
    include Controller::Action

    getter responses : Array(R.class) = {{@type.type_vars}}

    def initialize(@controller_metadata : Metadata, @action : Proc(Parameters, ::HTTP::Server::Context, R))
    end

    def call(parameters : Parameters, context : ::HTTP::Server::Context)
      @action.call parameters, context
    end
  end

  # :nodoc:
  struct RequestBodyAction(T, R)
    include Controller::Action

    getter request_body : RequestBodyTypes
    getter responses : Array(R.class) = Array(R.class).new

    def initialize(
      @controller_metadata : Metadata,
      @action : Proc(T, Parameters, ::HTTP::Server::Context, R),
      @request_body : RequestBodyTypes
    )
      {{@type.type_vars}}.each do |r|
        if r.is_a? R.class
          @responses << r
        end
      end
    end

    def call(parameters : Parameters, context : ::HTTP::Server::Context)
      casted_body = nil

      if body = context.request.body
        casted_body = case request_body = T
                      when RequestBody.class
                        request_body.from_io body
                      when String.class
                        body.gets_to_end
                      when IO.class
                        body
                      when Int.class, Float.class
                        request_body.new body.gets_to_end
                      when Nil.class
                        return UnexpectedRequestBody(T).new if !body.gets_to_end.empty?
                      else
                        return UnexpectedRequestBody(T).new
                      end
      elsif T != Nil
        return MissingRequestBody(T).new
      end
      @action.call casted_body.as(T), parameters, context
    end
  end

  {% for http_method in %w(POST PUT DELETE PATCH) %}
    # Creates a `{{ http_method.id }}` route, which accepts a `RequestBody`.
    #
    # A `RequestBody` type can be set to cast the response from a `String`.
    def {{http_method.downcase.id}}(
      *path,
      request_body : T.class,
      query_parameters : Array(Parameters::Query.class | String | Symbol)? = nil,
      summary : String? = nil,
      description : String? = nil,
      &action : T, Parameters, ::HTTP::Server::Context -> R
    ) forall T, R
      add_route(
        {{http_method}},
        path,
        RequestBodyAction(T, R).new(@metadata, action, T),
        query_parameters,
        summary,
        description,
      )
    end
  {% end %}

  {% for http_method in %w(GET CONNECT OPTIONS DELETE) %}
    # Creates a `{{ http_method.id }}` route.
    def {{http_method.downcase.id}}(
      *path,
      query_parameters : Array(Parameters::Query.class | String | Symbol)? = nil,
      summary : String? = nil,
      description : String? = nil,
      &action : Parameters, ::HTTP::Server::Context -> R
    ) forall R
      add_route(
        {{http_method}},
        path,
        NoRequestBodyAction(R).new(@metadata, action),
        query_parameters,
        summary,
        description,
      )
    end
  {% end %}

  # Creates a `HEAD` route, which does not return a response body.
  def head(
    *path,
    query_parameters : Array(Parameters::Query.class | String | Symbol)? = nil,
    summary : String? = nil,
    description : String? = nil,
    &action : Parameters, ::HTTP::Server::Context -> Nil
  )
    add_route(
      "HEAD",
      path,
      NoRequestBodyAction(Nil).new(@metadata, action),
      query_parameters,
      summary,
      description,
    )
  end
end
