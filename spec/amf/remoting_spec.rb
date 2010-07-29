require File.dirname(__FILE__) + '/../spec_helper.rb'

describe RocketAMF::Envelope do
  describe 'deserializer' do
    it "should handle remoting message from remote object" do
      req = create_envelope("remotingMessage.bin")

      req.headers.length.should == 0
      req.messages.length.should == 1
      message = req.messages[0].data
      message.should be_a(RocketAMF::Values::RemotingMessage)
      message.messageId.should == "FE4AF2BC-DD3C-5470-05D8-9971D51FF89D"
      message.body.should == [true]
    end

    it "should handle command message from remote object" do
      req = create_envelope("commandMessage.bin")

      req.headers.length.should == 0
      req.messages.length.should == 1
      message = req.messages[0].data
      message.should be_a(RocketAMF::Values::CommandMessage)
      message.messageId.should == "7B0ACE15-8D57-6AE5-B9D4-99C2D32C8246"
      message.body.should == {}
    end
  end

  describe 'serializer' do
    it "should serialize response when converted to string" do
      res = RocketAMF::Envelope.new
      res.should_receive(:serialize).and_return('serialized')
      res.to_s.should == 'serialized'
    end

    it "should serialize a simple call" do
      res = RocketAMF::Envelope.new :amf_version => 3
      res.messages << RocketAMF::Message.new('/1/onResult', '', 'hello')

      expected = request_fixture('simple-response.bin')
      res.serialize.should == expected
    end

    it "should serialize a AcknowledgeMessage response" do
      ak = RocketAMF::Values::AcknowledgeMessage.new
      ak.clientId = "7B0ACE15-8D57-6AE5-B9D4-99C2D32C8246"
      ak.messageId = "7B0ACE15-8D57-6AE5-B9D4-99C2D32C8246"
      ak.timestamp = 0
      res = RocketAMF::Envelope.new :amf_version => 3
      res.messages << RocketAMF::Message.new('/1/onResult', '', ak)

      expected = request_fixture('acknowledge-response.bin')
      res.serialize.should == expected
    end
  end

  describe 'message handler' do
    it "should respond to ping command" do
      res = RocketAMF::Envelope.new
      req = create_envelope('commandMessage.bin')
      res.each_method_call req do |method, args|
        nil
      end

      res.messages.length.should == 1
      res.messages[0].data.should be_a(RocketAMF::Values::AcknowledgeMessage)
    end

    it "should fail on unsupported command" do
      res = RocketAMF::Envelope.new
      req = create_envelope('unsupportedCommandMessage.bin')
      res.each_method_call req do |method, args|
        nil
      end

      res.messages.length.should == 1
      res.messages[0].data.should be_a(RocketAMF::Values::ErrorMessage)
      res.messages[0].data.faultString.should == "CommandMessage 10000 not implemented"
    end

    it "should handle RemotingMessages properly" do
      res = RocketAMF::Envelope.new
      req = create_envelope('remotingMessage.bin')
      res.each_method_call req do |method, args|
        method.should == 'WritesController.save'
        args.should == [true]
        true
      end

      res.messages.length.should == 1
      res.messages[0].data.should be_a(RocketAMF::Values::AcknowledgeMessage)
      res.messages[0].data.body.should == true
    end

    it "should catch exceptions properly" do
      res = RocketAMF::Envelope.new
      req = create_envelope('remotingMessage.bin')
      res.each_method_call req do |method, args|
        raise 'Error in call'
      end

      res.messages.length.should == 1
      res.messages[0].data.should be_a(RocketAMF::Values::ErrorMessage)
      res.messages[0].target_uri.should =~ /onStatus$/
    end

    it "should not crash if source missing on RemotingMessage" do
      res = RocketAMF::Envelope.new
      req = create_envelope('remotingMessage.bin')
      req.messages[0].data.instance_variable_set("@source", nil)
      lambda {
        res.each_method_call req do |method,args|
          true
        end
      }.should_not raise_error
    end
  end
end