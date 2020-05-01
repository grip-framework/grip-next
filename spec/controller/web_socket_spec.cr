require "../server_helper"
require "../../src/controller/web_socket"

struct WebSocketController < Gripen::Controller
  include Gripen::Controller::WebSocket
end

describe Gripen::Controller::WebSocket do
  controller = WebSocketController.new
  server = Gripen::Server.new controller: controller
  run_server server

  controller.websocket do |socket|
    socket.send "Hello"
  end
  it "casts the request body to a String" do
    ws = HTTP::WebSocket.new server.host, "/", server.port
    begin
      message = nil
      ws.on_message do |m|
        message = m
      end
      spawn { ws.run }
      sleep 0.1
      message.should eq "Hello"
    ensure
      ws.close
    end
  end
end
