# Gripen

[![Gitter](https://img.shields.io/badge/chat-on_gitter-red.svg?style=flat-square)](https://gitter.im/grip-framework/community)
[![ISC](https://img.shields.io/badge/License-ISC-blue.svg?style=flat-square)](https://en.wikipedia.org/wiki/ISC_license)

An HTTP Router in Crystal, with automatic [Swagger/OpenAPI](https://github.com/icyleaf/swagger) API docs generation.

## Features

The Gripen web framework emphasise on type safety. By defining expected types for requests and responses, it also provides documentation.

- Safe by returning an error at startup if routes conflict
- Automatic cast of requests and responses with defined types
- Automatic Swagger/OpenAPI documentation generation
- More type safety with less boilerplates
- Performance (at least on par with other web frameworks)
- Enforce standards (e.g. a `HEAD` route has no request body) 
- Simple, customizable and modular

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  gripen:
    github: grip-framework/gripen
```

## Documentation

https://grip-framework.github.io/gripen/

## Usage

Thanks to Crystal flexibility, route logic can be declared inside anonymous blocks or proc methods.

For more examples, see [EXAMPLES.md](EXAMPLES.md).

### Block based

Simple web server serving `"/"`:

```cr
require "gripen/server"
require "gripen/controller/default"

controller = Gripen::Controller::Default.new.add do
  get "public", :param, query_parameters: [:required, "optional"] do |params|
    params[:param] + params[:required]
  end

  post request_body: String do |body|
    body
  end
end

server = Gripen::Server.new controller

# Put the server in background
spawn { server.start }
sleep 0.5

p server.client.get("/public/hello?required=123").body # => "hello123"
p server.client.post("/", body: "hey!").body           # => "hey!"

```

### Proc based

```cr
require "gripen/server"
require "gripen/controller/http"
require "gripen/handler/logger"

struct MyController < Gripen::Controller
  include Gripen::Controller::HTTP
  @final = Gripen::Handler::Logger.new

  def get_public(params, context)
    params[:param] + params[:required]
  end

  def post(body, params, context)
    body
  end
end

class Server < Gripen::Server
  def routes
    add MyController do
      get "public",
        :param,
        query_parameters: [:required, "optional"],
        &->get_public(Gripen::Parameters, ::HTTP::Server::Context)

      post request_body: String,
        &->post(String, Gripen::Parameters, ::HTTP::Server::Context)
    end
  end
end

# Create a server with a default controller 
server = Server.new MyController.new

# Put the server in background
spawn { server.start }
sleep 0.5

p server.client.get("/public/hello?required=123").body # => "hello123"
p server.client.post("/", body: "hey!").body           # => "hey!"
```

## Swagger/OpenAPI documentation generation

Add [icyleaf/swagger](https://github.com/icyleaf/swagger) to the dependencies:

```yaml
dependencies:
  swagger:
    github: icyleaf/swagger
```

Run `shards install`

```cr
require "gripen/server"
require "gripen/controller/default"
require "gripen/docs"

server = Gripen::Server.new Gripen::Controller::Default.new
server.controller.docs_route
server.start
```
The API docs are now available at `http://localhost:3000/docs`.

## License

Copyright (c) 2020 Julien Reichardt - ISC License
