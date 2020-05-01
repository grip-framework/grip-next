require "./base"

# Executes when the route is found, and before the action.
# .
# Can be used to implement authentication for certain routes.
abstract class Gripen::Handler::Route
  include Base(Route)

  # Executes the route action if true, else jump directly to the `Finalizer`.
  abstract def call(context : HTTP::Server::Context) : Bool
end

# Does nothing by default, prevents a bug
private class Gripen::Handler::DefaultRoute < Gripen::Handler::Route
  def call(context : HTTP::Server::Context) : Bool
    true
  end
end
