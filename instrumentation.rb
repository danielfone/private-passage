#
# Handle logging and error reporting as well as sending metrics to AppSignal
#

require 'json'
require 'json/add/exception'
require 'eventmachine'
require 'appsignal'

if ENV['APPSIGNAL_PUSH_API_KEY']
  ENV['APPSIGNAL_APP_NAME'] = 'private-passenger-relay'
  ENV['APPSIGNAL_LOG'] = 'stdout'
  Appsignal.start
  Appsignal.start_logger

  # Ensure we call appsignal stop when the process exits
  at_exit do
    Appsignal.stop
  end
end

# Deal with errors from the eventmachine reactor
Thread.report_on_exception = false
EM.error_handler do |error|
  Instrumentation.log_exception(error, :eventmachine)
  raise
end


module Instrumentation

  # Rack middleware to log requests
  class Middleware
    def initialize(app)
      @app = app
      @appsignal = Appsignal::Rack::GenericInstrumentation.new(app)
    end

    def call(env)
      Instrumentation.measure('rack.request') do |attrs|
        status, _ = response = @appsignal.call(env)
        attrs.merge!(
          method: env['REQUEST_METHOD'],
          path: env['REQUEST_PATH'],
          status: status,
          origin: env['HTTP_ORIGIN'],
        )
        response
      end
    rescue Exception => error
      Instrumentation.log_exception(error, :http)
      raise
    end
  end

  # Log and report an exception
  def self.log_exception(error, source=:app)
    log "#{source}.error", error: error
    Appsignal.send_error(error)
  end

  def self.measure(action, attrs = {})
    start = monotonic_now if block_given? # Only measure the duration if we have a block
    # Appsignal.monitor_transaction("process_action.#{action}", **attrs) do
      yield attrs if block_given?
    # end
  ensure
    attrs[:action] = action
    if start
      # Log the duration
      duration = monotonic_now - start
      attrs[:duration_ms] = duration.round(3)
    end
    log(action, attrs)
  end

  # Log a message with key/value attributes
  def self.log(action, attrs = {})
    attr_list = JSON.generate(attrs) if attrs.any?
    puts "#{action} #{attr_list}"
  end

  # Get the monotonic time in milliseconds. This avoids issues with the system
  # clock changing.
  def self.monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
  end

end
