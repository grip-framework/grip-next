require "./action"
require "http/server/handlers/static_file_handler"

# Serves static files and list directories.
module Gripen::Controller::StaticFile
  struct Action
    include Controller::Action

    def initialize(@controller_metadata : Metadata, public_dir : String, fallthrough, directory_listing)
      @http_handler = ::HTTP::StaticFileHandler.new(
        public_dir: public_dir,
        fallthrough: fallthrough,
        directory_listing: directory_listing
      )
      @http_handler.next = ->(_context : ::HTTP::Server::Context) {}
    end

    def call(parameters : Parameters, context : ::HTTP::Server::Context)
      full_path = context.request.path
      context.request.path = parameters[FilesystemPath].path
      begin
        @http_handler.call context
      ensure
        context.request.path = full_path
      end

      nil
    end
  end

  struct FilesystemPath < Parameters::PathGlob
    getter path : String

    def initialize(@path)
    end

    def self.from_string(str)
      new str
    end
  end

  # Serves the files inside this directory.
  #
  # See stdlib `HTTP::StaticFileHandler` for more information
  def static_file(path : String, public_dir : String, fallthrough : Bool = true, directory_listing : Bool = true)
    {"GET", "HEAD"}.each do |method|
      add_route(
        method,
        {path, FilesystemPath},
        Action.new(@metadata, public_dir, fallthrough, directory_listing)
      )
    end
  end
end
