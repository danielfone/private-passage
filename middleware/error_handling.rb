require 'json'
require 'json/add/exception'

# This middleware will rescue all errors and return a 500 error
# response. It will also log the error to stdout.
class ErrorHandling

  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue Exception => error
    # Log the error
    warn "Uncaught Error #{JSON.generate(error)}}"
    # Internal server error
    [500, {}, ["Internal server error"]]
  end
end
