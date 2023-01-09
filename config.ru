require 'rack'
require_relative 'relay_server'

if ENV['APPSIGNAL_PUSH_API_KEY']
  require_relative 'appsignal'
  use Appsignal::Rack::GenericInstrumentation
end

use RelayServer
# Serve a simple health check
map('/ok') { run lambda { |_env| [204, {}, []] } }
# Serve static files
use Rack::Static, root: 'public', urls: ['/'], index: 'index.html'
run lambda { |_env| [404, {}, ['Not Found']] }
