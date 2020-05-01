require "./base"

# Executes at the end, always, typically used to log requests and errors.
abstract class Gripen::Handler::Final
  include Base(Final)

  # Call this operation, then the next one if defined.
  abstract def call(context : HTTP::Server::Context, elapsed_time : Time::Span, response_or_error : Exception | Response | Nil)
end
