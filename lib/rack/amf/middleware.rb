module Rack::AMF
  # Provide some helper items that can be included in the various middleware
  # being offered.
  module Middleware #:nodoc:
    APPLICATION_AMF = 'application/x-amf'.freeze

    # Standard middleware call method. Calls "handle" with the environment after
    # creating the request and response objects, and handles serializing the
    # response after the middleware is done.
    def call env #:nodoc:
      return @app.call(env) unless should_handle?(env)

      # Wrap request and response
      env['rack.input'].rewind
      env['rack-amf.request'] = RocketAMF::Request.populate_from_stream(env['rack.input'].read)
      env['rack-amf.response'] = RocketAMF::Response.new

      # Call handle on "inheriting" class
      handle env

      # Calculate length and return response
      response = env['rack-amf.response'].to_s
      [200, {"Content-Type" => APPLICATION_AMF, 'Content-Length' => response.length.to_s}, [response]]
    end

    # Check if we should handle it based on the environment
    def should_handle? env #:nodoc:
      return false unless env['CONTENT_TYPE'] == APPLICATION_AMF
      return false if Rack::AMF::Environment.url && env['PATH_INFO'] != Rack::AMF::Environment.url
      true
    end
  end
end