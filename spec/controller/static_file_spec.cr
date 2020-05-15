require "../server_helper"
require "../../src/controller/static_file"

struct StaticFileController < Gripen::Controller
  include Gripen::Controller::StaticFile
end

def with_temp_dir(tempdir, &)
  Dir.mkdir tempdir
  File.write tempdir / "file", "hello"
  yield
  File.delete tempdir / "file"
  Dir.rmdir tempdir.to_s
end

describe Gripen::Controller::StaticFile do
  controller = StaticFileController.new
  server = Gripen::Server.new controller: controller
  client = run_server server

  tempdir = Path.new File.tempname
  controller.static_file "/", tempdir.to_s

  it "lists files and directories" do
    with_temp_dir tempdir do
      response = client.get "/"
      response.status.should eq HTTP::Status::OK
      response.body.should contain "/file"
    end
  end

  it "gets a file" do
    with_temp_dir tempdir do
      response = client.get "/file"
      response.status.should eq HTTP::Status::OK
      response.body.should eq "hello"
    end
  end
end
