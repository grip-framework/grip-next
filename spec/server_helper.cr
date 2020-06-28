require "../src/server"
require "../src/controller/http"
require "spec"

struct TestHTTPController < Gripen::Controller
  include Gripen::Controller::HTTP
end

def run_server(server)
  server.log.backend.as(Log::IOBackend).io = File.open File::NULL, "w"

  client = server.client

  around_all do |example|
    spawn { server.start }
    sleep 0.5
    example.run
  ensure
    server.stop
  end

  before_each { client.close }

  client
end
