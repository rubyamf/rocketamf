require 'rack/amf/middleware'

module Rack::AMF::Middleware #:nodoc:
  # Middleware which simply passes AMF requests through. Sets env['rack-amf.request']
  # to the Rack::AMF::Request object and env['rack-amf.response'] to the
  # Rack::AMF::Response object. Simply modify the response as necessary and it
  # will be automatically serialized and sent.
  class PassThrough
    include Rack::AMF::Middleware

    def initialize app, options={}
      @app = app
      Rack::AMF::Environment.populate options
    end

    def handle
      @app.call env
    end
  end
end