require File.dirname(__FILE__) + '/../spec_helper.rb'
require 'rack/amf'

describe Rack::AMF::Response do
  it "should serialize response when converted to string" do
    response = Rack::AMF::Response.new(create_rack_request('commandMessage.bin'))
    response.raw_response.should_receive(:serialize).and_return('serialized')
    response.to_s.should == 'serialized'
  end

  it "should respond to ping command" do
    response = Rack::AMF::Response.new(create_rack_request('commandMessage.bin'))
    response.each_method_call {|method, args| nil}

    r = response.raw_response
    r.messages.length.should == 1
    r.messages[0].data.should be_a(AMF::Values::AcknowledgeMessage)
  end

  it "should handle RemotingMessages properly" do
    response = Rack::AMF::Response.new(create_rack_request('remotingMessage.bin'))

    response.each_method_call do |method, args|
      method.should == 'WritesController.save'
      args.should == [true]
      true
    end

    r = response.raw_response
    r.messages.length.should == 1
    r.messages[0].data.should be_a(AMF::Values::AcknowledgeMessage)
    r.messages[0].data.body.should == true
  end

  it "should catch exceptions properly" do
    response = Rack::AMF::Response.new(create_rack_request('remotingMessage.bin'))
    response.each_method_call do |method, args|
      raise 'Error in call'
    end

    r = response.raw_response
    r.messages.length.should == 1
    r.messages[0].data.should be_a(AMF::Values::ErrorMessage)
    r.messages[0].target_uri.should =~ /onStatus$/
  end
end