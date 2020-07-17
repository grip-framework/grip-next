# Gripen Examples

- [Controllers](#controllers)
- [Handlers](#handlers)
- [Request body](#request-body)
- [Path parameters](#path-parameters)
- [Query parameters](#query-parameters)
- [Response](#response)

## Controllers

Controllers are objects holding a set of routes, which usually shares a common path prefix, handlers and usually a same logic.

```cr
require "gripen/controller"
require "gripen/controller/http"

struct Controller < Gripen::Controller
  include Gripen::Controller::HTTP
end

controller = Controller.new("api", "public", name: "Public API")
```

## Handlers

Handlers are operations triggered at certain times of the request processing.

There are 2 types:

| name    | description                                        | examples                        |
| --------| ---------------------------------------------------| --------------------------------|
| Route   | Called when the route is found                     | Authentication                  |
| Final   | Called at the very end of the request processing   | Logger                          |

## Request Body

Several requests can accept a request body like `POST`, other not, like `GET`.

```cr
require "gripen/controller"
require "gripen/controller/http"

struct Controller < Gripen::Controller
  include Gripen::Controller::HTTP
end

controller = Controller.new

struct ExampleBody < Gripen::Controller::HTTP::RequestBody
  getter int : Int32

  def initialize(@int : Int32)
  end

  def self.from_io(body : IO)
    new body.gets_to_end.to_i
  end
end


controller.post "public", request_body: ExampleBody do |body, params, context|
  typeof(body) # => ExampleBody
  body.int
end
```

## Path parameters

Path parameters allows to have variables inside a path.

There are usually referenced as `{Param}` or `/:param/` in web frameworks.

Path components can be separated by `/` or `,`, but path parameters always by a semi-colon `,`.

```cr
require "gripen/controller"

struct Controller < Gripen::Controller
  include Gripen::Controller::HTTP
end

controller = Controller.new

struct ExampleID < Gripen::Parameters::Path
  getter id : Int32

  def initialize(@id : Int32)
  end

  def self.from_string(str : String)
    new str.to_i
  end
end

controller.get "api/public", ExampleID do |params, context|
  example_id = params[ExampleID]
  typeof(example_id) # => ExampleID 
  example_id.id
end
```

## Query parameters

Query parameters are values assigned at the end of the path (https://en.wikipedia.org/wiki/Query_string).

Two types of queries exists: required and optional.

```cr
require "gripen/controller"

struct RequiredExample < Gripen::Parameters::RequiredQuery
  getter num : Int32
  class_getter parameter_name = "height"

  def initialize(@num : Int32)
  end

  def self.from_string(str : String)
    new str.to_i
  end
end

struct OptionalExample < Gripen::Parameters::OptionalQuery
  getter num : Int32
  class_getter parameter_name = "height"

  def initialize(@num : Int32)
  end

  def self.from_string(str : String)
    new str.to_i
  end
end

struct Controller < Gripen::Controller
  include Gripen::Controller::HTTP
end

controller = Controller.new

controller.add do
  get "example", query_parameters: [OptionalExample, RequiredExample] do |params|
    optional, required = params[OptionalExample, RequiredExample]
    typeof(optional) # => OptionalExample | Nil
    typeof(required) # => RequiredExample
    nil
  end
end
```

## Response

A response to send to the client can be a regular `String` but can also be typed.

In this below example, a `SomeUser` object will be returned with a HTTP status code `201 Created`.

```cr
require "gripen/controller"

struct SomeUser
  include Gripen::Response
  class_getter response_info = Gripen::Response::Info.new "User created", http_status: :CREATED, content_type: "application/json"

  def add_response(context)
    context.response << %({"name": "myuser"})
  end
end

struct Controller < Gripen::Controller
  include Gripen::Controller::HTTP
end

Controller.new.get { SomeUser.new }
```
