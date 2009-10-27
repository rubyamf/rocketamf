require File.dirname(__FILE__) + '/../spec_helper.rb'

describe AMF::Request do
  it "should handle remoting message from remote object" do
    req = create_request("remotingMessage.bin")

    req.headers.length.should == 0
    req.messages.length.should == 1
    message = req.messages[0].data
    message.should be_a(AMF::Values::RemotingMessage)
    message.messageId.should == "FE4AF2BC-DD3C-5470-05D8-9971D51FF89D"
    message.body.should == [true]
  end

  it "should handle command message from remote object" do
    req = create_request("commandMessage.bin")

    req.headers.length.should == 0
    req.messages.length.should == 1
    message = req.messages[0].data
    message.should be_a(AMF::Values::CommandMessage)
    message.messageId.should == "7B0ACE15-8D57-6AE5-B9D4-99C2D32C8246"
    message.body.should == {}
  end
end
