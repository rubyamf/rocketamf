require File.dirname(__FILE__) + '/../spec_helper.rb'
require 'rack/amf'
require 'rack/amf/middleware/service_manager'

describe Rack::AMF::Middleware::ServiceManager do
  before :each do
    @manager = Rack::AMF::Middleware::ServiceManager.new nil
  end

  it "should support mapped services" do
    service = mock "Service", :test => 'success'
    Rack::AMF::Environment.register_service 'path.Service', service
    service.should_receive('test').with('arg1', 'arg2')

    @manager.send(:handle_method, 'path.Service.test', ['arg1', 'arg2']).should == 'success'
  end

  it "should map '' to no path method calls" do
    service = mock "Service", :test => 'success'
    Rack::AMF::Environment.register_service '', service
    service.should_receive('test')

    @manager.send(:handle_method, 'test', []).should == 'success'
  end
end