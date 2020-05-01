require "spec"
require "../src/controller"

struct TestController < Gripen::Controller
  struct Action
    include Gripen::Controller::Action

    def initialize(@controller_metadata : Metadata, @action : Proc(Nil))
    end

    def call(parameters : Gripen::Parameters, context : ::HTTP::Server::Context)
    end
  end

  def route(method, *path)
    add_route method, path, action: Action.new(@metadata, ->{})
  end
end

struct TestPathParameter < Gripen::Parameters::Path
  def self.from_string(str)
  end
end

describe Gripen::Controller do
  it "creates one with metadata" do
    TestController.new "api", "public", name: "Public API"
  end

  it "adds a route" do
    TestController.new.route "GET", "path"
  end

  it "adds a route with a path parameter" do
    TestController.new.route "GET", TestPathParameter, "path"
  end

  it "adds a route with a prefix" do
    controller = TestController.new
    controller.add "api" do
      route "GET", "public"
    end
    ex = expect_raises Gripen::Controller::Error do
      controller.route "GET", "/api/public"
    end
    ex.cause.should be_a Gripen::Controller::PathActions::Error::MethodAlreadyDefined
    ex.message.as(String).should contain "GET /api/public"
  end

  it "raises for an invalid method" do
    TestController.new.add do
      ex = expect_raises Gripen::Controller::Error do
        route "NotStandardMethod", "path"
      end
      ex.cause.should be_a Gripen::Controller::PathActions::Error::InvalidMethod
      ex.message.as(String).should contain "NotStandardMethod /path"
    end
  end

  it "raises for a route conflict" do
    TestController.new.add do
      route "POST", "path"
      ex = expect_raises Gripen::Controller::Error do
        route "POST", "path"
      end
      ex.cause.should be_a Gripen::Controller::PathActions::Error::MethodAlreadyDefined
      ex.message.as(String).should contain "POST /path"
    end
  end

  it "raises for a route conflict with a path parameter" do
    TestController.new.add do
      route "GET", TestPathParameter
      ex = expect_raises Gripen::Controller::Error do
        route "GET", "path"
      end
      ex.cause.should be_a Gripen::Router::Node::RouteConflict
      ex.message.as(String).should contain "GET /path"
    end
  end

  it "merges (<<) two controllers" do
    main_controller = TestController.new.tap &.route "GET", "path"
    other_controller = TestController.new.tap &.route "GET", "other_path"
    main_controller << other_controller
    ex = expect_raises Gripen::Controller::Error do
      main_controller.route "GET", "other_path"
    end
    ex.cause.should be_a Gripen::Controller::PathActions::Error::MethodAlreadyDefined
    ex.message.as(String).should contain "GET /other_path"
  end

  it "lists paths" do
    controller = TestController.new "api"
    controller.route "GET", "path"
    paths = String.build do |str|
      controller.paths str
    end
    paths.should start_with "GET /api/path (Controller: \"Api\")"
  end
end
