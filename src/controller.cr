require "./parameters"
require "./response"
require "./handler/route"
require "./handler/final"
require "./controller/route_resolver"

# Controllers are objects holding a set of routes, which usually shares a common path prefix, handlers and usually a same logic.
#
# ```
# require "gripen/controller"
#
# struct Controller < Gripen::Controller
# end
#
# metadata = Gripen::Controller::Metadata.new "Public API"
# controller = Controller.new("api", "public", metadata)
#
# controller << Controller.new.add do
#   # Declare routes
# end
# ```
abstract struct Gripen::Controller
  alias PathType = String | Parameters::PathType

  include RouteResolver

  # Controller's metadata, used for documentation generation.
  struct Metadata
    # Controller's name. Should be unique among other controllers.
    #
    # By default if not set, has the `Controller#path_prefix` as a name.
    getter name : String

    # Controller description.
    getter description : String? = nil

    def initialize(@name : String, @description : String? = nil)
    end
  end

  # Path prefix to preprend to all route paths.
  getter path_prefix : Array(PathType)
  # Controller metadata.
  getter metadata : Metadata
  # Handler executing before the action.
  getter route : Handler::Route?
  # Final handler executing at the end.
  getter final : Handler::Final?
  # Route tree of nodes which holds paths with their actions.
  getter route_nodes : Router::Node(Parameters::PathType, PathActions) = Router::Node(Parameters::PathType, PathActions).new

  # ```
  # require "gripen"
  #
  # struct Controller < Gripen::Controller
  # end
  #
  # controller = Controller.new("api", "public", name: "Public API")
  # ```
  def initialize(
    *path_prefix,
    name : String? = nil,
    description : String? = nil,
    route : Handler::Route? = nil,
    final : Handler::Final? = nil
  )
    @route = route if route
    @final = final if final
    @metadata = Metadata.new (name || path_prefix.join(' ').camelcase), description
    @path_prefix = paths_to_array path_prefix
  end

  private def paths_to_array(
    path_prefix,
    path_dest : Array(PathType) = Array(PathType).new
  )
    path_prefix.each do |path_or_param|
      # support / separated path
      if path_or_param.is_a? String
        path_or_param.split('/', remove_empty: true) do |path|
          path_dest << path
        end
      else
        path_dest << path_or_param
      end
    end
    path_dest
  end

  private def format_path(paths : Array(PathType)) : String
    return "/" if paths.empty?
    String.build do |str|
      paths.each do |path|
        str << '/'
        case path
        when String then str << path
        else             str << '{' << pretty_path_name(path) << '}'
        end
      end
    end
  end

  # Returns a pretty name of the path class.
  private def pretty_path_name(path : PathType) : String
    return path.to_s if path.is_a?(Symbol) || path.is_a?(String)
    String.build do |str|
      str << '*' if Parameters.path_glob? path
      str << path.to_s.rpartition("::").last
    end
  end

  private def add_route(
    method : String,
    path,
    action : Action,
    query_params : Array(Parameters::Query.class | String | Symbol)? = nil,
    summary : String? = nil,
    description : String? = nil
  )
    path_array = paths_to_array path, @path_prefix.dup

    # For the potential error message, because the array is consumed
    pretty_path = format_path path_array

    action.add_query_params query_params
    action.summary = summary
    action.description = description
    action.route = @route
    action.final = @final
    begin
      path_actions = @route_nodes.add path_array do
        PathActions.new
      end
      path_actions.add method, action
    rescue ex
      raise Error.new "Failed to add route: #{method} #{pretty_path}", cause: ex
    end
  end

  # Adds a routes using the default controller `Controller::Default`.
  #
  # This is an easy way to create routes. For more features, use `Gripen#<`
  # to add a specific controller.
  #
  # ```
  # require "gripen"
  #
  # struct Controller < Gripen::Controller
  #   include Gripen::Controller::HTTP
  # end
  #
  # Controller.new.add do
  #   get "public" do
  #   end
  # end
  # ```
  #
  def add(&)
    with self yield
    self
  end

  # Creates a child controller based on this one.
  def child(*prefix, route : Handler::Route? = @route, final : Handler::Final? = @final)
    child = self.class.new(
      *prefix,
      name: @metadata.name,
      description: @metadata.description,
      route: route || @route,
      final: final || @final
    )
    @path_prefix.each do |path|
      child.path_prefix.unshift path
    end
    child
  end

  # Yields child `Controller` based on the current one, with a specific prefix to add.
  #
  # This is an easy way to create a set of routes sharing a same path prefix, but belonging to a same controller.
  #
  # For more features, use `#<<` to add a specific controller.
  #
  # ```
  # require "gripen"
  #
  # struct Controller
  #   include Gripen::Controller
  #   include Gripen::Controller::HTTP
  # end
  #
  # controller = Controller.new "api"
  # controller.add "public" do
  #   get { }
  # end
  # ```
  #
  def add(*prefix, route : Handler::Route? = @route, final : Handler::Final? = @final, &)
    controller = child *prefix, route: route, final: final
    with controller yield
    self << controller
  end

  # Merges routes of a controller inside this current one.
  #
  # ```
  # require "gripen"
  #
  # struct Controller < Gripen::Controller
  #   include Gripen::Controller::HTTP
  # end
  #
  # main_controller = Controller.new
  # other_controller = Controller.new
  # other.add do
  #   get "public" do
  #   end
  # end
  #
  # main_controller << other_controller
  # ```
  def <<(controller : Controller)
    @route_nodes.merge! controller.route_nodes do |existing, other|
      existing.merge! other
    end
    self
  end

  # Print paths in a human-readable format to the given `IO`.
  def paths(io : IO = STDOUT) : Nil
    @route_nodes.each_path do |path_array, path_action|
      path = format_path path_array
      path_action.each do |method, action|
        io << method << ' ' << path
        if query_parameters = action.query_parameters
          io << '?'
          first = true
          query_parameters.each do |name, query|
            io << '&' if !first
            io << name << '=' << query
            first = false
          end
        end
        io << " (Controller: \"" << action.controller_metadata.name << "\")"
        io.puts
      end
    end
  end
end

require "./controller/action"
require "./controller/path_actions"
