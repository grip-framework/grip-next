require "./action"

# Holds available actions of a path.
class Gripen::Controller::PathActions
  class Error < Controller::Error
    class MethodAlreadyDefined < Error
    end

    class InvalidMethod < Error
    end

    class MethodConflict < Error
    end
  end

  property get : Action? = nil,
    head : Action? = nil,
    post : Action? = nil,
    put : Action? = nil,
    delete : Action? = nil,
    patch : Action? = nil,
    connect : Action? = nil,
    options : Action? = nil,
    trace : Action? = nil

  # Returns the action matching the method (in upper-case).
  def from_method(method : String) : Action?
    {% begin %}
      case method
      {% for method in @type.instance_vars %}
      when {{method.stringify.upcase}} then @{{method}}
      {% end %}
      else # unsupported action
      end
    {% end %}
  end

  # Adds an action for a given upper-case method. Raises if already present.
  def add(method : String, action : Action)
    {% begin %}
      case method
      {% for method in @type.instance_vars %}
      when {{method.stringify.upcase}}
        raise Error::MethodAlreadyDefined.new "Action already present for the method #{method}: #{@{{method}}}" if @{{method}}
        @{{method}} = action
      {% end %}
      else
        raise Error::InvalidMethod.new "Invalid method: #{method}"
      end
    {% end %}
  end

  # Yields each defined method.
  def each(& : String, Action ->)
    {% for method in @type.instance_vars %}
    if {{method}} = @{{method}}
      yield {{method.stringify.upcase}}, {{method}}
    end
    {% end %}
  end

  # Merges a PathAction to another.
  def merge!(other : PathActions)
    other.each do |method, action|
      add method, action
    end
  end

  # Returns `true` if no actions are available.
  def empty? : Bool
    {% for method in @type.instance_vars %}
    return false if @{{method}}
    {% end %}
    true
  end
end
