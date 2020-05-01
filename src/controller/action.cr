require "http/params"
require "http/server"

# Base module to include for a controller action.
module Gripen::Controller::Action
  module Error
    struct InvalidQueryParameterName
      include Response
      class_getter response_info = Response::Info.new "Invalid query parameter name", http_status: ::HTTP::Status::BAD_REQUEST

      def initialize(parameter)
        @error_message = "#{@@response_info.description}: #{parameter}"
      end

      def add_response(context : ::HTTP::Server::Context)
        context.response.puts @@response_info.description
      end
    end

    struct UnexpectedQueryParameters
      include Response
      class_getter response_info = Response::Info.new "Unexpected query parameters", http_status: ::HTTP::Status::BAD_REQUEST

      def initialize(query : String)
        @error_message = "#{@@response_info.description}: #{query}"
      end

      def add_response(context : ::HTTP::Server::Context)
        context.response.puts @@response_info.description
      end
    end
  end

  # A short summary of what the operation does.
  property summary : String? = nil
  # A verbose explanation of the operation behavior. [CommonMark](http://spec.commonmark.org/) syntax MAY be used for rich text representation.
  property description : String? = nil
  # Query parameters.
  getter query_parameters : Hash(String, Parameters::Query.class | String | Symbol)?
  property route : Handler::Route? = nil
  property final : Handler::Final? = nil

  # Used to know more efficiently if a required query is missing, and which one.
  protected getter required_queries : Array(Parameters::RequiredQuery.class | Symbol)?

  # Metadata from the controller this action belongs to.
  getter controller_metadata : Metadata

  abstract def call(parameters : Parameters, context : ::HTTP::Server::Context)

  def add_query_params(query_params_list : Array(Parameters::Query.class | String | Symbol)?)
    if query_params_list
      query_parameters = Hash(String, Parameters::Query.class | String | Symbol).new
      query_params_list.each do |query|
        if query.is_a?(String) || query.is_a?(Symbol)
          query_name = query.to_s
        else
          query_name = query.parameter_name
        end
        query_parameters[query_name] = query
        if required_query = Parameters.required_query? query
          required_queries = @required_queries || Array(Parameters::RequiredQuery.class | Symbol).new
          required_queries << required_query
          @required_queries = required_queries
        end
      end
    end
    @query_parameters = query_parameters
  end

  protected def handle_query(query : String?, & : Parameters::Query.class | String | Symbol, String ->)
    if query
      unless query_parameters = @query_parameters
        return Error::UnexpectedQueryParameters.new query
      end
      ::HTTP::Params.parse(query) do |parameter, value|
        unless query_param = query_parameters[parameter]?
          return Error::InvalidQueryParameterName.new parameter
        end
        yield query_param, value
      end
    end
  end
end
