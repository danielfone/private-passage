require 'appsignal'
require 'eventmachine'

Appsignal.config = Appsignal::Config.new(
  File.expand_path('../', __FILE__),          # Application root path
  ENV['RACK_ENV'],                            # Application environment
  name: 'Private Passage Relay Server',       # Application name
  log: 'stdout'
)

if ENV['APPSIGNAL_PUSH_API_KEY']
  Appsignal.start
  Appsignal.start_logger
end

# Deal with errors from the eventmachine reactor used by faye-websocket
Thread.report_on_exception = false
EM.error_handler do |error|
  warn "Uncaught Error (EventMachine) #{JSON.generate(error)}}"
  Appsignal.send_error(error)
  raise
end
