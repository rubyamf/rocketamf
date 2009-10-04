require 'rack/amf/request'
require 'rack/amf/response'

module Rack::AMF
  class Application
    def initialize app, mode
      @app = app
      @mode = mode
    end

    def call env
      if env['CONTENT_TYPE'] != APPLICATION_AMF
        return [200, {"Content-Type" => "text/plain"}, ["Hello From Rack::AMF"]]
      end

      # Wrap request and response
      env['amf.request'] = Request.new(env)
      env['amf.response'] = Response.new(env['amf.request'])

      # Handle request
      if @mode == :pass_through
        @app.call env
      elsif @mode == :internal
        # Have the service manager handle it
        Services.handle(env)
      end

      response = env['amf.response'].to_s
      [200, {"Content-Type" => APPLICATION_AMF, 'Content-Length' => response.length.to_s}, [response]]
    end
  end
end