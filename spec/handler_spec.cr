require "./server_helper"
require "../src/handler"
require "../src/handler"

class RouteTest < Gripen::Handler::Route
  def call(context : HTTP::Server::Context) : Bool
    context.response << "route"
    false
  end
end

class FinalTest < Gripen::Handler::Final
  def call(context : HTTP::Server::Context, elapsed_time : Time::Span, response_or_error : Exception | Gripen::Response | Nil)
    context.response << "final"
  end
end

describe Gripen::Handler do
  controller = TestHTTPController.new "/", route: RouteTest.new, final: FinalTest.new
  server = Gripen::Server.new controller: controller
  client = run_server server

  it "compiles compress handler" do
    Gripen::Handler::Compress.new
  end

  controller.get { }
  it "executes the route handler" do
    response = client.get "/"
    response.status.should eq HTTP::Status::OK
    response.body.should eq "routefinal"
  end

  it "executes the final handler" do
    response = client.get "nofound_route"
    response.status.should eq HTTP::Status::NOT_FOUND
    response.body.should eq "Not Found\nfinal"
  end
end
