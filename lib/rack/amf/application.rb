require 'rack/amf/request'
require 'rack/amf/response'

module Rack::AMF
  class Application
    def initialize app, options={}
      @app = app
      @options = {:mode => :internal, :url => nil}.merge(options)
    end

    def call env
      # Check if we should handle it
      return @app.call(env) if env['CONTENT_TYPE'] != APPLICATION_AMF
      return @app.call(env) if @options[:url] && env['PATH_INFO'] != @options[:url]

      # Wrap request and response
      env['rack-amf.request'] = Request.new(env)
      env['rack-amf.response'] = Response.new(env['rack-amf.request'])

      # Handle request
      if @options[:mode] == :pass_through
        @app.call env
      elsif @options[:mode] == :internal
        # Have the service manager handle it
        Services.handle(env)
      end

      # Calculate length and return response
      response = env['rack-amf.response'].to_s
      [200, {"Content-Type" => APPLICATION_AMF, 'Content-Length' => response.length.to_s}, [response]]
    end
  end
end