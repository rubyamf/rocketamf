require 'rack'
require 'amf'
require 'rack/amf/environment'

module Rack::AMF
  def self.new app, options={} #:nodoc:
    # Set default mode
    options[:mode] = :service_manager if !options[:mode]

    # Which version of the middleware?
    if options[:mode] == :pass_through
      require 'rack/amf/middleware/pass_through'
      Middleware::PassThrough.new(app, options)
    elsif options[:mode] == :service_manager
      require 'rack/amf/middleware/service_manager'
      Middleware::ServiceManager.new(app, options)
    else
      raise "Invalide mode: #{options[:mode]}"
    end
  end
end