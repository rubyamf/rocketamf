module Rack::AMF
  module Environment
    class << self
      attr_accessor :url, :mode, :debug, :services
      debug = false # Set to off by default

      # Used to register a service for use with the ServiceManager middleware.
      # To register a service, simply pass in the root path for the service and
      # an object that can receive service calls.
      #
      # Example:
      #
      #   Rack::AMF::Environment.register_service 'SpecialService', SpecialService.new
      #   Rack::AMF::Environment.register_service 'org.rack-amf.AMFService', AMFService.new
      def register_service path, service
        @services ||= {}
        @services[path] = service
      end

      # Populates the environment from the given options hash, which was passed
      # in through rack
      def populate options={} #:nodoc:
        url = options[:url] if options.key?(:url)
        debug = options[:debug] if options.key?(:debug)
        mode = options[:mode] if options.key?(:mode)
      end

      def log data #:nodoc:
        return if !debug
        puts data
      end
    end
  end
end