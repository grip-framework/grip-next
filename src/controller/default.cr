require "./http"
require "../handler/logger"

# Default controller.
struct Gripen::Controller::Default < Gripen::Controller
  include Controller::HTTP
  @final = Gripen::Handler::Logger.new
end
