require File.dirname(__FILE__) + '/../spec_helper.rb'

describe AMF::Response do
  it "should serialize response when converted to string" do
    res = AMF::Response.new
    res.should_receive(:serialize).and_return('serialized')
    res.to_s.should == 'serialized'
  end

  it "should serialize a simple call" do
    res = AMF::Response.new
    res.amf_version = 3
    res.messages << AMF::Message.new('/1/onResult', '', 'hello')

    expected = request_fixture('simple-response.bin')
    res.serialize.should == expected
  end

  it "should serialize a AcknowledgeMessage response" do
    ak = AMF::Values::AcknowledgeMessage.new
    ak.clientId = "7B0ACE15-8D57-6AE5-B9D4-99C2D32C8246"
    ak.messageId = "7B0ACE15-8D57-6AE5-B9D4-99C2D32C8246"
    ak.timestamp = 0
    res = AMF::Response.new
    res.amf_version = 3
    res.messages << AMF::Message.new('/1/onResult', '', ak)

    expected = request_fixture('acknowledge-response.bin')
    res.serialize.should == expected
  end

  it "should respond to ping command" do
    res = AMF::Response.new
    req = create_request('commandMessage.bin')
    res.each_method_call req do |method, args|
      nil
    end

    res.messages.length.should == 1
    res.messages[0].data.should be_a(AMF::Values::AcknowledgeMessage)
  end

  it "should handle RemotingMessages properly" do
    res = AMF::Response.new
    req = create_request('remotingMessage.bin')
    res.each_method_call req do |method, args|
      method.should == 'WritesController.save'
      args.should == [true]
      true
    end

    res.messages.length.should == 1
    res.messages[0].data.should be_a(AMF::Values::AcknowledgeMessage)
    res.messages[0].data.body.should == true
  end

  it "should catch exceptions properly" do
    res = AMF::Response.new
    req = create_request('remotingMessage.bin')
    res.each_method_call req do |method, args|
      raise 'Error in call'
    end

    res.messages.length.should == 1
    res.messages[0].data.should be_a(AMF::Values::ErrorMessage)
    res.messages[0].target_uri.should =~ /onStatus$/
  end
end