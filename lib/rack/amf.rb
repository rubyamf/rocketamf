require 'rack'
require 'amf'

require 'rack/amf/application'
require 'rack/amf/service_manager'
require 'rack/amf/request'
require 'rack/amf/response'

module Rack::AMF
  APPLICATION_AMF = 'application/x-amf'.freeze

  Services = Rack::AMF::ServiceManager.new

  def self.new app, mode=:internal
    Rack::AMF::Application.new(app, mode)
  end
end