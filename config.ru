require 'rack'
require_relative 'relay_server'
require_relative 'instrumentation'


# A simple health check
map('/ok') { run lambda { |_env| [204, {}, []] } }

# Instrument all other requests
use Instrumentation::Middleware

# Serve the websocket
run RelayServer.new
