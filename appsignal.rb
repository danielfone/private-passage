require 'appsignal'                           # Load AppSignal

Appsignal.config = Appsignal::Config.new(
  File.expand_path('../', __FILE__),          # Application root path
  ENV['RACK_ENV'],                            # Application environment
  name: 'Private Passage Relay Server',       # Application name
  log: 'stdout'
)

Appsignal.start                               # Start the AppSignal integration
Appsignal.start_logger                        # Start logger
