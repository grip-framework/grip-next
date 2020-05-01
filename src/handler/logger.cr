require "./final"

# Default logger.
class Gripen::Handler::Logger < Gripen::Handler::Final
  # Ouput (stdout) `IO`. to write request logs.
  property output : IO

  # Error (stderr) `IO` to write error logs.
  property error : IO

  def initialize(@output : IO = STDOUT, @error : IO = STDERR)
  end

  def call(context : HTTP::Server::Context, elapsed_time : Time::Span, response_or_error : Exception | Response | Nil)
    current_time = Time.utc
    log_request context, current_time, elapsed_time
    if response_or_error
      log_error current_time, response_or_error
    end
  end

  # Prints error backtraces to `#error`.
  def log_error(current_time : Time, response_or_error : Exception | Response)
    exception = nil

    write_time current_time, @error
    @error << ' '

    if response_or_error.is_a? Response
      response_or_error.error_message.try &.to_s @error
      @error << " (" << response_or_error.class << ')'

      exception = response_or_error.exception_cause
      if !exception
        @error.puts
        @error.flush
      end
    end

    if response_or_error.is_a? Exception
      exception = response_or_error
    end

    if exception
      exception.inspect_with_backtrace @error
      @error.flush
    end
  end

  # Writes a log with request information and elapsed time.
  def log_request(context : HTTP::Server::Context, current_time : Time, elapsed_time : Time::Span)
    write_time current_time, @output
    @output << ' '
    log_request context, current_time
    @output << ' '
    write_elapsed_time elapsed_time
    @output.puts
  end

  # Write log request information.
  def log_request(context : HTTP::Server::Context, current_time : Time)
    @output << context.response.status_code << ' ' << context.request.method << ' ' << context.request.resource
  end

  # Writes time to the given `IO` in the RFC 3339 format.
  def write_time(current_time : Time, io : IO)
    current_time.to_rfc3339 io
  end

  # Writes elapsed time at the end of the request log entry.
  def write_elapsed_time(elapsed : Time::Span)
    minutes = elapsed.total_minutes
    if minutes < 1
      @output << elapsed.total_seconds.humanize(precision: 2, significant: false) << 's'
    else
      @output << minutes.round(2) << 'm'
    end
  end
end
