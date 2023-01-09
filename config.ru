require 'rack'
require_relative 'appsignal'
require_relative 'relay_server'

# Generic middlware to run a proc before the request
class Middleware
  def initialize(app, proc)
    @app = app
    @proc = proc
  end

  def call(env)
    @proc.call(env)
    @app.call(env)
  end
end

# Use Appsignal to instrument the request and report errors
use Appsignal::Rack::GenericInstrumentation

# Serve the websocket
map('/ws') do
  use Middleware, lambda { |env| env['appsignal.route'] = 'websocket' }
  run RelayServer.new
end

# Serve a simple health check
map('/ok') do
  use Middleware, lambda { |env| env['appsignal.route'] = 'health' }
  run lambda { |_env| [204, {}, []] }
end

# Fallback to serving static files
use Middleware, lambda { |env| env['appsignal.route'] = 'static' }
use Rack::Static, urls: ['/'], root: 'public', index: 'index.html'
run lambda { |_| [404, {}, ['Not Found']] }
