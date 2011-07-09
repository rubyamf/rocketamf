require "spec_helper.rb"

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

  describe 'request builder' do
    it "should create simple call" do
      req = RocketAMF::Envelope.new
      req.call('TestController.test', 'first_arg', 'second_arg')

      expected = request_fixture('simple-request.bin')
      req.serialize.should == expected
    end

    it "should allow multiple simple calls" do
      req = RocketAMF::Envelope.new
      req.call('TestController.test', 'first_arg', 'second_arg')
      req.call('TestController.test2', 'first_arg', 'second_arg')

      expected = request_fixture('multiple-simple-request.bin')
      req.serialize.should == expected
    end

    it "should create flex remoting call" do
      req = RocketAMF::Envelope.new :amf_version => 3
      req.call_flex('TestController.test', 'first_arg', 'second_arg')
      req.messages[0].data.timestamp = 0
      req.messages[0].data.messageId = "9D108E33-B591-BE79-210D-F1A72D06B578"

      expected = request_fixture('flex-request.bin')
      req.serialize.should == expected
    end

    it "should require AMF version 3 for remoting calls" do
      req = RocketAMF::Envelope.new :amf_version => 0
      lambda {
        req.call_flex('TestController.test')
      }.should raise_error("Cannot use flex remoting calls with AMF0")
    end

    it "should require all calls be the same type" do
      req = RocketAMF::Envelope.new :amf_version => 0
      lambda {
        req.call('TestController.test')
        req.call_flex('TestController.test')
      }.should raise_error("Cannot use different call types")
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

  describe 'response parser' do
    it "should return the result of a simple response" do
      req = RocketAMF::Envelope.new
      req.call('TestController.test', 'first_arg', 'second_arg')
      res = RocketAMF::Envelope.new
      res.each_method_call req do |method, args|
        ['a', 'b']
      end

      res.result.should == ['a', 'b']
    end

    it "should return the results of multiple simple response in a single request" do
      req = RocketAMF::Envelope.new
      req.call('TestController.test', 'first_arg', 'second_arg')
      req.call('TestController.test2', 'first_arg', 'second_arg')
      res = RocketAMF::Envelope.new
      res.each_method_call req do |method, args|
        ['a', 'b']
      end

      res.result.should == [['a', 'b'], ['a', 'b']]
    end

    it "should return the results of a flex response" do
      req = RocketAMF::Envelope.new :amf_version => 3
      req.call_flex('TestController.test', 'first_arg', 'second_arg')
      res = RocketAMF::Envelope.new
      res.each_method_call req do |method, args|
        ['a', 'b']
      end
      res.result.should == ['a', 'b']
    end
  end
end