require File.dirname(__FILE__) + '/../spec_helper.rb'
require 'rack/amf'

describe Rack::AMF::ServiceManager do
  before :each do
    @manager = Rack::AMF::ServiceManager.new
  end

  it "should support mapped services" do
    service = mock "Service"
    @manager.register('path.Service', service)
    service.should_receive('respond_to?').with('test').and_return(true)
    service.should_receive('test').with('arg1', 'arg2').and_return('success')

    @manager.send(:handle_method, 'path.Service.test', ['arg1', 'arg2']).should == 'success'
  end

  it "should map '' to no path method calls" do
    service = mock "Service"
    @manager.register('', service)
    service.should_receive('respond_to?').with('test').and_return(true)
    service.should_receive('test').and_return('success')

    @manager.send(:handle_method, 'test', []).should == 'success'
  end
end