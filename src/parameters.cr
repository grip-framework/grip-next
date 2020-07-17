require "gripen_router"
require "./errors"
require "./response"

# Object holding query and path parameters.
#
# Both path and query parameters need  to implement the `.from_string` class method.
#
# It will cast a parameter string to the object. When the cast fails,
# both raising an exception or returning `nil` (prevents raising an exception, which can be expensive).
struct Gripen::Parameters
  alias PathType = Parameters::Path.class | GlobPath.class | Symbol

  # A HTTP path parameter.
  #
  # **Must** implements `.from_string(str : String)`
  # ```
  # require "gripen/parameters"
  #
  # struct ExamplePath < Gripen::Parameters::Path
  #   def initialize(@val : Int32)
  #   end
  #
  #   def self.from_string(str : String)
  #     new str.to_i
  #   end
  # end
  # ```
  abstract struct Path
  end

  # Special path parameter, which takes the path segment and all remaing ones following it.
  #
  # **Must** implements `.from_string(str : String)`
  abstract struct GlobPath < Parameters::Path
    include Router::GlobPath
  end

  class Error < Gripen::Error
    struct InvalidValue
      include Response
      class_getter response_info = Response::Info.new "Invalid parameter value", http_status: :BAD_REQUEST

      private def initialize(@description : String, parameter, value, @exception_cause)
        @error_message = "#{@description}: #{value} (parameter: #{parameter})"
      end

      def self.new(parameter : Parameters::Path.class | Symbol, value, cause = nil)
        new "Invalid path parameter value", parameter, value, exception_cause: cause
      end

      def self.new(parameter : Query.class | String | Symbol, value, cause = nil)
        new "Invalid query parameter value", parameter, value, exception_cause: cause
      end

      def add_response(context : HTTP::Server::Context)
        context.response.puts @description
      end
    end

    struct DuplicatedKey
      include Response
      class_getter response_info = Response::Info.new "Duplicated parameter", http_status: :BAD_REQUEST

      private def initialize(@description : String, parameter, value, @exception_cause)
        @error_message = "#{@description}: #{value} (parameter: #{parameter})"
      end

      def self.new(parameter : Parameters::Path.class | Symbol, value, cause = nil)
        new "Duplicated path parameter", parameter, value, exception_cause: cause
      end

      def self.new(parameter : Query.class | String | Symbol, value, cause = nil)
        new "Duplicated query parameter", parameter, value, exception_cause: cause
      end

      def add_response(context : HTTP::Server::Context)
        context.response.puts @description
      end
    end

    class PathOrRequiredQueryNotFound < Error
    end

    class PathNotFound < Error
    end

    class QueryNotFound < Error
    end

    class GlobPathNotFound < Error
    end

    class NoParametersAvailable < Error
    end

    struct MissingRequiredQuery
      include Response
      class_getter response_info = Response::Info.new "Missing query parameter", http_status: :BAD_REQUEST
      @description : String

      def initialize(query)
        if query.is_a?(String) || query.is_a?(Symbol)
          query_name = query.to_s
        else
          query_name = query.parameter_name
        end
        @description = "Missing query parameter: " + query_name
        @error_message = "#{@description} (query: #{query})"
      end

      def add_response(context : ::HTTP::Server::Context)
        context.response.puts @description
      end
    end
  end

  alias Query = OptionalQuery | RequiredQuery

  private abstract struct BaseQuery
  end

  # An optional HTTP query parameter.
  #
  # **Must** implements `.from_string(str : String)` and `.parameter_name : String`.
  #
  # ```
  # require "gripen/parameters"
  #
  # struct ExampleOptionalQuery < Gripen::Parameters::OptionalQuery
  #   class_getter parameter_name = "optional"
  #
  #   def initialize(@val : Int32)
  #   end
  #
  #   def self.from_string(str : String)
  #     new str.to_i
  #   end
  # end
  # ```
  abstract struct OptionalQuery < BaseQuery
  end

  # An required HTTP query parameter.
  #
  # **Must** implements `.from_string(str : String)` and `.parameter_name : String`.
  #
  # ```
  # require "gripen/parameters"
  #
  # struct ExampleRequiredQuery < Gripen::Parameters::RequiredQuery
  #   class_getter parameter_name = "optional"
  #
  #   def initialize(@val : Int32)
  #   end
  #
  #   def self.from_string(str : String)
  #     new str.to_i
  #   end
  # end
  # ```
  abstract struct RequiredQuery < BaseQuery
  end

  # Required to prevent having the error https://github.com/crystal-lang/crystal/issues/8853
  private module InheritanceBugFix
    private struct GlobPath < GlobPath
      def self.from_string(str)
      end
    end

    private struct RequiredQuery < RequiredQuery
      class_getter parameter_name = ""

      def self.from_string(str)
      end
    end
  end

  private getter parameters : Hash(PathType | Query.class | String, String | Parameters::Path | Query | GlobPath) do
    Hash(PathType | Query.class | String, String | Parameters::Path | Query | GlobPath).new
  end

  private def parameters!
    @parameters || raise Error::NoParametersAvailable.new "No parameters available"
  end

  # :nodoc:
  protected def add(parameter, value : String, & : Error::InvalidValue | Error::DuplicatedKey ->) : Nil
    if parameter.is_a?(Symbol) || parameter.is_a?(String)
      parameters.put(parameter, value) { return }
      yield Error::DuplicatedKey.new parameter, value
    elsif path = parameter.from_string value
      parameters.put(parameter, path) { return }
      yield Error::DuplicatedKey.new parameter, value
    else
      yield Error::InvalidValue.new parameter, value
    end
  rescue ex
    yield Error::InvalidValue.new parameter, value, ex
  end

  private def fetch(parameter : Parameters::Path.class)
    parameters![parameter]? || raise Error::PathNotFound.new "Path parameter not found: #{parameter}"
  end

  private def fetch(parameter : RequiredQuery.class)
    parameters![parameter]? || raise Error::QueryNotFound.new "Query parameter not found: #{parameter}"
  end

  private def fetch(parameter : GlobPath.class)
    parameters![parameter]? || raise Error::GlobPathNotFound.new "Path glob not found: #{parameter}"
  end

  private def fetch?(parameter : OptionalQuery.class)
    @parameters.try &.[parameter]?
  end

  # Returns a required path/query parameter.
  def [](path_or_query : Symbol) : String
    if value = parameters![path_or_query]?
      value.as String
    else
      raise Error::PathOrRequiredQueryNotFound.new "Parameter not found: #{path_or_query}"
    end
  end

  # Returns an optional query parameter.
  def []?(query_parameter : String) : String?
    if value = @parameters.try &.[query_parameter]?
      value.as String
    end
  end

  # Returns a path parameter.
  def [](parameter : T.class) : T forall T
    fetch(T).as T
  end

  # Returns a query parameter, and returns `nil` if not found.
  #
  # Only `Parameters::OptionalQuery` parameters can be optional,
  # that is why there is no nillable `[]?` method for path parameters.
  def []?(optional_query : T.class) : T? forall T
    fetch?(T).try &.as T
  end

  # Returns multiple parameters as a `Tuple`.
  def [](*types : *T) forall T
    {% begin %}
    {
      {% for klass in T %}
        self[{{klass.instance}}]{% if klass.ancestors[0] == OptionalQuery.class %}?{% end %},
      {% end %}
    }
    {% end %}
  end

  protected def check(count : Int32, required_queries : Array(RequiredQuery.class | Symbol)?, & : Error::MissingRequiredQuery ->)
    return if !required_queries
    if count != required_queries.size
      required_queries.each do |query|
        if !@parameters.try &.has_key? query
          yield Error::MissingRequiredQuery.new query
        end
      end
    end
  end

  # Returns a required query.
  #
  # An optioal query can also be a string ending with `?`.
  def self.required_query?(query : RequiredQuery.class | Symbol) : RequiredQuery.class | Symbol
    query
  end

  # Returns `Nil`.
  def self.required_query?(query) : Nil
    nil
  end

  def self.path_glob?(path : GlobPath.class) : GlobPath.class
    path
  end

  def self.path_glob?(path) : Nil
    nil
  end
end
