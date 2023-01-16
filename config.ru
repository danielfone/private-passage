require 'rack'
require_relative 'middleware/error_handling'
require_relative 'relay_server'

# Catch all errors and return a 500 error
use ErrorHandling

# A simple health check
map('/ok') { run lambda { |_env| [204, {}, []] } }

# Serve the websocket
run RelayServer.new
