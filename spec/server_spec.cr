require "./spec_helper"
require "kemal"

include Kemal

def harpy_call_request(request : HTTP::Request)
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  Kemal.config.setup
  main_handler = Kemal.config.handlers.first
  current_handler = main_handler
  Kemal.config.handlers.each do |handler|
    current_handler.not_nil!.next = handler
    current_handler = handler
  end
  main_handler.not_nil!.call(context)
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, decompress: false)
end

def harpy_test_response(method : String, path : String, body : String? = nil)
  Kemal.config.clear
  Kemal::FilterHandler::INSTANCE.tree = Radix::Tree(Array(Kemal::FilterHandler::FilterBlock)).new
  Kemal::RouteHandler::INSTANCE.routes = Radix::Tree(Kemal::Route).new
  Kemal::RouteHandler::INSTANCE.cached_routes =
    Kemal::LRUCache(String, Radix::Result(Kemal::Route)).new(Kemal.config.max_route_cache_size)
  Kemal::WebSocketHandler::INSTANCE.routes = Radix::Tree(Kemal::WebSocket).new

  storage_path = File.tempname
  Harpy::Storage.save(Harpy::SpecHelpers.build_chain(1), storage_path)
  Harpy::Server.reset!(storage_path)
  Harpy::Server.configure_kemal!
  Harpy::Server.register_routes!

  request = HTTP::Request.new(method, path)
  request.headers["Content-Type"] = "application/json"

  if body
    request.body = IO::Memory.new(body.to_slice)
    request.headers["Content-Length"] = body.bytesize.to_s
  end

  harpy_call_request(request)
ensure
  File.delete?(storage_path) if storage_path && File.exists?(storage_path)
end

describe "POST /new-block request limits" do
  it "rejects HTTP bodies larger than the configured limit with 413" do
    oversized = %({"data":"#{"x" * (Harpy::Config.max_request_body_bytes + 1)}"})
    response = harpy_test_response("POST", "/new-block", oversized)

    response.status_code.should eq(413)
    response.body.should eq(%({"error":"request body too large"}))
  end

  it "rejects block data larger than the configured cap with 400" do
    payload = %({"data":"#{"y" * (Harpy::Config.max_block_data_bytes + 1)}"})
    response = harpy_test_response("POST", "/new-block", payload)

    response.status_code.should eq(400)
    response.body.should eq(%({"error":"block data exceeds maximum size"}))
  end

  it "accepts block data within the configured cap" do
    payload = %({"data":"#{"z" * (Harpy::Config.max_block_data_bytes - 20)}"})
    response = harpy_test_response("POST", "/new-block", payload)

    response.status_code.should eq(200)
    JSON.parse(response.body)["data"].as_s.bytesize.should eq(Harpy::Config.max_block_data_bytes - 20)
  end
end
