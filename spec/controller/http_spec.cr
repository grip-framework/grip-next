require "../server_helper"

struct UserID < Gripen::Parameters::Path
  getter id : Int32

  def initialize(@id : Int32)
  end

  def self.from_string(str : String)
    new str.to_i
  end
end

struct PathGlob < Gripen::Parameters::GlobPath
  getter path

  def initialize(@path : String)
  end

  def self.from_string(str : String)
    new str
  end
end

struct Group < Gripen::Parameters::Path
  getter name : String

  def initialize(@name : String)
  end

  def self.from_string(str : String)
    new str
  end
end

struct RequiredHeight < Gripen::Parameters::RequiredQuery
  getter size : Int32
  class_getter parameter_name = "height"

  def initialize(@size : Int32)
  end

  def self.from_string(str : String)
    new str.to_i
  end
end

struct OptionalHeight < Gripen::Parameters::OptionalQuery
  getter size : Int32
  class_getter parameter_name = "height"

  def initialize(@size : Int32)
  end

  def self.from_string(str : String)
    new str.to_i
  end
end

struct Body < Gripen::Controller::HTTP::RequestBody
  getter int : Int32

  def initialize(@int : Int32)
  end

  def self.from_io(body : IO)
    new body.gets_to_end.to_i
  end
end

struct User
  include Gripen::Response
  class_getter response_info = Gripen::Response::Info.new "User created", http_status: ::HTTP::Status::CREATED, content_type: "application/json"

  def add_response(context)
    context.response << "myuser"
  end
end

struct UserError
  include Gripen::Response
  class_getter response_info = Gripen::Response::Info.new "Invalid user", http_status: ::HTTP::Status::BAD_REQUEST, content_type: "application/json"

  def add_response(context)
    context.response << @@response_info.description
  end
end

describe Gripen::Controller::HTTP do
  controller = TestHTTPController.new
  server = Gripen::Server.new controller: controller
  client = run_server server

  describe "POST" do
    controller.post "str", request_body: String do |body|
      body
    end
    it "casts the request body to a String" do
      response = client.post "/str", body: "Hello"
      response.status.should eq HTTP::Status::OK
      response.body.should eq "Hello"
    end

    controller.add do
      post "req_body", request_body: Body do |body|
        body.int
      end
    end
    it "should cast body with a RequestBody type" do
      response = client.post "/req_body", body: "123"
      response.status.should eq HTTP::Status::OK
      response.body.should eq "123"
    end

    controller.add do
      post "int", request_body: Int32 do |body|
        body
      end
    end
    it "should cast body with a Int type" do
      response = client.post "/int", body: "123"
      response.status.should eq HTTP::Status::OK
      response.body.should eq "123"
    end

    controller.post "nil", request_body: Nil do
    end
    it "accepts an empty body" do
      response = client.post "/nil"
      response.status.should eq HTTP::Status::OK
    end
  end

  describe "DELETE" do
    controller.delete { "hello" }
    it "returns ok with no request body" do
      response = client.delete "/"
      response.status.should eq HTTP::Status::OK
      response.body.should eq "hello"
    end

    controller.add do
      delete("req_body", request_body: String) do |body|
        body
      end
    end
    it "returns ok with a request body" do
      response = client.delete "/req_body", body: "hello"
      response.status.should eq HTTP::Status::OK
      response.body.should eq "hello"
    end
  end

  describe "PATCH" do
    controller.add do
      patch(request_body: String) do |body|
        body
      end
    end
    it "returns ok" do
      response = client.patch "/", body: "123"
      response.status.should eq HTTP::Status::OK
      response.body.should eq "123"
    end
  end

  describe "PUT" do
    controller.add do
      put(request_body: String) do |body|
        body
      end
    end
    it "returns ok with an empty body" do
      response = client.put "/", body: "123"
      response.status.should eq HTTP::Status::OK
      response.body.should eq "123"
    end
  end

  describe "GET" do
    controller.get { "hello" }
    it "returns ok" do
      response = client.get "/"
      response.status.should eq HTTP::Status::OK
      response.body.should eq "hello"
    end

    controller.get "/user_response" { User.new }
    it "returns a Response::Base" do
      response = client.get "/user_response"
      response.status.should eq HTTP::Status::CREATED
      response.body.should eq "myuser"
      response.content_type.should eq "application/json"
    end

    controller.get "/user_error" { UserError.new }
    it "returns a Response::Error" do
      response = client.get "/user_error"
      response.status.should eq HTTP::Status::BAD_REQUEST
      response.body.should eq "Invalid user"
      response.content_type.should eq "application/json"
    end

    controller.get "/a/b/c" { "hello" }
    it "returns ok on / separated path declaration" do
      response = client.get "/a/b/c"
      response.status.should eq HTTP::Status::OK
      response.body.should eq "hello"
    end

    controller.add do
      get "groups", "list", description: "Some text" do
        "group"
      end
    end
    it "routes correctly a simple path" do
      response = client.get "/groups/list"
      response.status.should eq HTTP::Status::OK
      response.body.should eq "group"
    end

    it "returns not found" do
      response = client.get "/NotFound"
      response.status.should eq HTTP::Status::NOT_FOUND
    end
  end

  describe "HEAD" do
    controller.head "head" { "hello" }
    it "returns ok with an empty body" do
      response = client.head "/head"
      response.status.should eq HTTP::Status::OK
      response.body.should eq ""
    end

    it "returns a 405 Method Not Allowed" do
      response = client.get "/head"
      response.status.should eq HTTP::Status::METHOD_NOT_ALLOWED
    end
  end

  it "lists paths" do
    controller = TestHTTPController.new "api"

    controller.post "req_body", UserID, query_parameters: [OptionalHeight], request_body: Body do |body|
      body.int
    end

    paths = String.build do |str|
      controller.paths str
    end

    paths.should start_with "POST /api/req_body/{UserID}?height=OptionalHeight (Controller: \"Api\")"
  end

  describe "parameters" do
    describe "query" do
      it "returns bad request for unexpected query parameters" do
        response = client.get "/?a=b"
        response.status.should eq HTTP::Status::BAD_REQUEST
      end

      controller.add "users" do
        get "required_query", query_parameters: [RequiredHeight] do |params|
          params[RequiredHeight].size
        end
      end
      it "parses a required query" do
        response = client.get "/users/required_query?height=1"
        response.status.should eq HTTP::Status::OK
        response.body.should eq "1"
      end

      it "returns bad request on duplicated query parameters" do
        response = client.get "/users/required_query?height=1&height=1"
        response.status.should eq HTTP::Status::BAD_REQUEST
        response.body.should start_with "Duplicated "
      end

      it "returns bad request on missing required query parameters" do
        response = client.get "/users/required_query"
        response.status.should eq HTTP::Status::BAD_REQUEST
        response.body.should start_with "Missing "
      end

      controller.add "users" do
        get "optional_query", query_parameters: [OptionalHeight] do |params|
          params[OptionalHeight]?.try &.size
        end
      end
      it "parses a present optional query" do
        response = client.get "/users/optional_query?height=1"
        response.status.should eq HTTP::Status::OK
        response.body.should eq "1"
      end
      it "parses a missing optional query" do
        response = client.get "/users/optional_query"
        response.status.should eq HTTP::Status::OK
        response.body.should be_empty
      end

      controller.get "query_string/optional", query_parameters: ["first"] do |params|
        params["first"]?
      end
      it "parses an optional query string" do
        response = client.get "/query_string/optional?first=str"
        response.status.should eq HTTP::Status::OK
        response.body.should eq "str"
      end
      it "returns empty on missing optional query string" do
        response = client.get "/query_string/optional"
        response.status.should eq HTTP::Status::OK
        response.body.should be_empty
      end

      controller.get "query_string/required", query_parameters: [:first] do |params|
        params[:first]
      end
      it "returns bad request on on missing required query string" do
        response = client.get "/query_string/required"
        response.status.should eq HTTP::Status::BAD_REQUEST
        response.body.should start_with "Missing "
      end
    end

    describe "path" do
      controller.get "path_glob", PathGlob do |params|
        params[PathGlob].path
      end
      it "gets a path glob" do
        path = "/some/unknown/path"
        response = client.get "/path_glob" + path
        response.status.should eq HTTP::Status::OK
        response.body.should eq path
      end

      it "gets an empty path glob" do
        response = client.get "/path_glob"
        response.status.should eq HTTP::Status::OK
        response.body.should be_empty
      end

      controller.add "users" do
        get "test", UserID, Group do |params|
          user_id, group = params[UserID, Group]
          user_id.id
          group.name
        end
      end
      it "routes a path with path parameters" do
        response = client.get "/users/test/123/admin"
        response.status.should eq HTTP::Status::OK
        response.body.should eq "admin"
      end

      controller.get "symbol_param", :param do |params|
        params[:param]
      end
      it "routes a symbol path parameters" do
        response = client.get "/symbol_param/some_value"
        response.status.should eq HTTP::Status::OK
        response.body.should eq "some_value"
      end
    end
  end
end
