require 'rack'
require_relative 'relay_server'

if ENV['APPSIGNAL_PUSH_API_KEY']
  require_relative 'appsignal'
  use Appsignal::Rack::GenericInstrumentation
end

# Serve the websocket
map('/ws') do
  run RelayServer.new
end

# Serve a simple health check
map('/ok') do
  run lambda { |_env| [204, {}, []] }
end

# Fallback to serving static files
use Rack::Static, root: 'public', urls: ['/'], index: 'index.html'
run lambda { |_env| [404, {}, ['Not Found']] }
