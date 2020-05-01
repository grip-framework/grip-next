require "./controller"
require "swagger"
require "ecr"

module Gripen::Controller::HTTP
  abstract struct RequestBody
  end

  class DocsError < Error
  end

  # Version of the OpenAPI document (distrinct from the OpenAPI specification version or the application version).
  property openapi_document_version : String = "0.1.0"

  # Returns a `Swagger::Info` from a `Controller::Metadata`
  private def swagger_info : Swagger::Info
    Swagger::Info.new(
      title: @metadata.name,
      version: @openapi_document_version,
      description: @metadata.description
    )
  end

  # Generates Swagger/OpenAPI docs.
  #
  # ```
  # require "gripen/docs"
  #
  # struct Controller < Gripen::Controller
  # end
  #
  # Controller.new.docs.to_pretty_json STDOUT
  # ```
  #
  # Can be tested on https://editor.swagger.io/.
  def docs : Swagger::Document
    paths = Hash(String, Swagger::Objects::PathItem).new
    tags = Set(Swagger::Objects::Tag).new
    @route_nodes.each_path do |path_array, path_actions|
      string_path = format_path path_array
      path_item = Swagger::Objects::PathItem.new
      path_actions.each do |method, action|
        # Add request body
        if action.is_a? RequestBodyAction
          case action.request_body
          when Int32.class, Int64.class
            type = "integer"
            format = action.request_body.to_s.downcase
          when Float32.class
            type = "number"
            format = "float"
          when Float64.class
            type = "number"
            format = "double"
          else
            type = "string"
            format = nil
          end

          if !action.request_body.is_a? Nil.class
            # TODO: proper media type
            content = Hash(String, Swagger::Objects::MediaType).new
            content["text/plain"] = Swagger::Objects::MediaType.new(
              schema: Swagger::Objects::Schema.new(
                type: type,
                format: format
              )
            )
            required = true
          else
            required = false
          end

          request_body = Swagger::Objects::RequestBody.new(
            description: nil, # TODO: use annotation for description
            content: content,
            required: required,
          )
        end

        parameters = Array(Swagger::Objects::Parameter).new

        # Add path parameters
        path_array.each do |path|
          if path.is_a? Parameters::PathType
            parameters << Swagger::Objects::Parameter.new(
              name: pretty_path_name(path),
              parameter_location: :path,
              schema: Swagger::Objects::Schema.new type: "string", format: nil
            )
          end
        end

        # Add query parameters
        action.query_parameters.try &.each do |name, query_type|
          parameters << Swagger::Objects::Parameter.new(
            name: name,
            parameter_location: :query,
            required: !!Parameters.required_query?(query_type),
            schema: Swagger::Objects::Schema.new type: "string", format: nil
          )
        end

        # Add tag, information about the controller
        tag = Swagger::Objects::Tag.new(
          name: action.controller_metadata.name,
          description: action.controller_metadata.description
        )
        tags << tag

        # By default the server responds with a 200
        responses = Hash(String, Swagger::Objects::Response).new
        case action
        when RequestBodyAction, NoRequestBodyAction
          action.responses.each do |response|
            add_response response, responses
          end
        else # Nothing to do
        end

        operation = Swagger::Objects::Operation.new(
          summary: action.summary,
          description: action.description,
          tags: [action.controller_metadata.name],
          parameters: parameters,
          request_body: request_body,
          responses: responses,
          deprecated: false,
          security: nil,
        )
        path_item.add method.downcase, operation
      end

      paths[string_path] = path_item
    end

    Swagger::Document.new(
      info: swagger_info,
      servers: nil,
      tags: tags.to_a,
      paths: paths,
      components: nil
    )
  end

  private def add_response(response : Gripen::Response.class, responses)
    status_code = response.response_info.http_status.code.to_s
    encoding = {"*" => Swagger::Objects::Encoding.new}
    content = {
      response.response_info.content_type => Swagger::Objects::MediaType.new(
        encoding: encoding
      ),
    }

    responses[status_code] = Swagger::Objects::Response.new(
      description: response.response_info.description,
      content: content
    )
  end

  private def add_response(other, responses) : Nil
    responses[Response.response_info.http_status.code.to_s] = Swagger::Objects::Response.new Response.response_info.description
  end

  # Adds a route serving this controller `#docs`, along one to serve the OpenAPI's json.
  #
  # ```
  # require "gripen"
  # require "gripen/docs"
  #
  # struct Controller < Gripen::Controller
  # end
  #
  # Controller.new.docs
  # ```
  def docs_route(
    docs_path : String = "docs",
    openapi_path : String = "swagger.json",
    title : String = "API Documentation",
    development : Bool = false
  )
    if @path_prefix.includes? Parameters::Path.class
      raise DocsError.new "The path prefix cannot include a path parameter: #{format_path @path_prefix}"
    end
    document = docs.to_json

    openapi_path_array = paths_to_array [openapi_path], @path_prefix.dup
    # Used in the ECR template
    # ameba:disable Lint/UselessAssign
    openapi_url = format_path openapi_path_array

    api_page = ECR.render "./lib/swagger/src/swagger/http/views/swagger.ecr"

    # Nil is used to prevent interfering with the Result handlers
    get docs_path, summary: title do |_, context|
      context.response.headers["Content-Type"] = "text/html"
      context.response << api_page
      nil
    end
    get openapi_path, summary: title do |_, context|
      context.response.headers["Content-Type"] = "application/json"
      context.response << document
      nil
    end
  end
end
