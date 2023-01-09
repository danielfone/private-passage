require 'json'

#
# JSON formatted request logging middleware for Rack.
#
#   Processed request {"method":"GET","path":"/","status":200,"duration_ms":0.0}
#
# The request is logged as soon as the response is ready. The body may not have been
# fully read at this point.
#
class RequestLogger

  def initialize(app)
    @app = app
  end

  def call(env)
    start = monotonic_time
    status, _headers, _body = @app.call(env)
  ensure
    finish = monotonic_time
    # Log the request
    log(
      "Processed request",
      method: env['REQUEST_METHOD'],
      path: env['REQUEST_URI'],
      status: status,
      duration_ms: (finish - start).round(3),
    )
  end

private

  # Returns the current time in milliseconds. Monotonic time is used to avoid
  # issues with system time changes
  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
  end


  def log(message, attrs = {})
    attr_json = JSON.generate(attrs) unless attrs.empty?
    puts "#{message} #{attr_json}"
  end
end
