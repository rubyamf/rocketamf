require 'rack/amf/middleware'

module Rack::AMF::Middleware #:nodoc:
  # Internal AMF handler, it uses the ServiceManager to handle request service
  # mapping.
  class ServiceManager
    include Rack::AMF::Middleware

    def initialize app, options={}
      @app = app
      Rack::AMF::Environment.populate options
    end

    def handle env
      env['rack-amf.response'].each_method_call env['rack-amf.request'] do |method, args|
        handle_method method, args
      end
    end

    private
    def handle_method method, args
      path = method.split('.')
      method_name = path.pop
      path = path.join('.')

      s = Rack::AMF::Environment.services
      if s[path]
        if s[path].respond_to?(method_name)
          s[path].send(method_name, *args)
        else
          raise "Service #{path} does not respond to #{method_name}"
        end
      else
        raise "Service #{path} does not exist"
      end
    end
  end
end