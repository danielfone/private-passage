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
    duration = (finish - start).round(3)
    # Log the request
    log(
      "HTTP response #{status} #{duration}ms #{env['REQUEST_METHOD']} #{env['REQUEST_URI']}",
      type: :http_request,
      method: env['REQUEST_METHOD'],
      path: env['REQUEST_PATH'],
      status: status,
      duration_ms: duration,
      origin: env['HTTP_ORIGIN'],
    )
  end

private

  # Returns the current time in milliseconds. Monotonic time is used to avoid
  # issues with system time changes
  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
  end


  def log(message, attrs = {})
    attr_json = JSON.generate(attrs.compact) unless attrs.empty?
    puts "#{message} #{attr_json}"
  end
end
