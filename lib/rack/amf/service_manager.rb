module Rack::AMF
  class ServiceManager
    def initialize
      @services = {}
    end

    def register path, service
      @services ||= {}
      @services[path] = service
    end

    def handle env
      env['rack-amf.response'].each_method_call do |method, args|
        handle_method method, args
      end
    end

    private
    def handle_method method, args
      path = method.split('.')
      method_name = path.pop
      path = path.join('.')

      if @services[path]
        if @services[path].respond_to?(method_name)
          @services[path].send(method_name, *args)
        else
          raise "Service #{path} does not respond to #{method_name}"
        end
      else
        raise "Service #{path} does not exist"
      end
    end
  end
end