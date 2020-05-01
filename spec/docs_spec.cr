require "../src/docs"
require "./server_helper"

struct TestDocsPathParameter < Gripen::Parameters::Path
  def self.from_string(str)
  end
end

struct DocPath < Gripen::Parameters::Path
  getter id : Int32

  def initialize(@id : Int32)
  end

  def self.from_string(str : String)
    new str.to_i
  end
end

struct DocRequestBody < Gripen::Controller::HTTP::RequestBody
  getter int : Int32

  def initialize(@int : Int32)
  end

  def self.from_io(body : IO)
    new body.gets_to_end.to_i
  end
end

struct OptionalDocQuery < Gripen::Parameters::OptionalQuery
  getter size : Int32
  class_getter parameter_name = "optional_query"

  def initialize(@size : Int32)
  end

  def self.from_string(str : String)
    new str.to_i
  end
end

struct UserExample
  include Gripen::Response
  class_getter response_info = Gripen::Response::Info.new "User created", http_status: ::HTTP::Status::CREATED, content_type: "application/json"

  def add_response(context)
  end
end

describe "Gripen::Controller#docs" do
  main_controller = TestHTTPController.new "api"
  server = Gripen::Server.new controller: main_controller
  client = run_server server

  main_controller.get "public", query_parameters: [OptionalDocQuery], summary: "Summary", description: "Description" { }
  main_controller.post("public", DocPath, request_body: DocRequestBody) { UserExample.new }
  main_controller.add "other" do
    post DocPath, request_body: Int32 do
    end
  end

  it "generates docs" do
    main_controller.docs # .to_pretty_json STDOUT
  end

  it "creates a docs route" do
    main_controller.docs_route
    docs_response = client.get "/api/docs"
    docs_response.status.should eq HTTP::Status::OK
    docs_response.headers["Content-Type"]?.should eq "text/html"

    swagger_response = client.get "/api/swagger.json"
    swagger_response.status.should eq HTTP::Status::OK
    swagger_response.headers["Content-Type"]?.should eq "application/json"
    # sleep 20
  end
end
