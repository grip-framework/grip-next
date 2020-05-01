# :nodoc:
abstract struct Gripen::Controller
  module RouteResolver
    class Error < Gripen::Error
      struct MethodNotAllowed
        include Response
        class_getter response_info = Response::Info.new http_status: ::HTTP::Status::METHOD_NOT_ALLOWED

        def add_response(context : ::HTTP::Server::Context)
          context.response.puts @@response_info.description
        end
      end

      struct NotFound
        include Response
        class_getter response_info = Response::Info.new http_status: ::HTTP::Status::NOT_FOUND

        def add_response(context : ::HTTP::Server::Context)
          context.response.puts @@response_info.description
        end
      end
    end

    abstract def route : Handler::Route?
    abstract def final : Handler::Final?
    abstract def route_nodes : Router::Node(Parameters::PathType, PathActions)

    # Resolves a route from a `HTTP::Server::Context`.
    def resolve_route(context : ::HTTP::Server::Context) : Nil
      response_or_error = nil
      route_final = @final

      time = Time.measure do
        response_or_error = handle_request context do |final|
          route_final = final || @final
        end
      rescue ex
        response_or_error = ex
      ensure
        case local_result = response_or_error
        when Response
          local_result.send_response context
        when Exception
          context.response.respond_with_status :internal_server_error
        else # No response/error
        end
      end

      call_handler route_final, context, time, response_or_error
    end

    private def handle_request(context : ::HTTP::Server::Context) : Exception | Response | Nil
      parameters = Parameters.new

      path_action = @route_nodes.find context.request.path do |parameter, value|
        parameters.add parameter, value do |ex|
          return ex
        end
      end
      if action = path_action.try &.from_method context.request.method
        yield action.final

        required_queries = 0
        response_or_error = action.handle_query context.request.query do |query_param, value|
          required_queries += 1 if Parameters.required_query? query_param
          parameters.add query_param, value do |ex|
            return ex
          end
        end
        return response_or_error if response_or_error
        parameters.check required_queries, action.required_queries do |ex|
          return ex
        end
        if call_bool_handler action.route, context
          case result = action.call parameters, context
          when Response, Exception then return result
          else                          context.response << result
          end
        end
      elsif path_action && !path_action.empty?
        return Error::MethodNotAllowed.new
      else
        return Error::NotFound.new
      end
      nil
    end

    # Calls the handler, and then the next one, if any, if the result of the former is true.
    private def call_bool_handler(handler : Handler::Route?, context : ::HTTP::Server::Context) : Bool
      if handler
        return false if !handler.call context
        if next_handler = handler.next
          call_bool_handler next_handler, context
        end
      end
      true
    end

    # Calls the handler, and then the next one if any.
    private def call_handler(handler : Handler::Final?, *args)
      return if !handler
      handler.call *args
      if next_handler = handler.next
        call_handler next_handler, *args
      end
    end
  end
end
