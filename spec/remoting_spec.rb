require File.dirname(__FILE__) + '/spec_helper.rb'

describe "when handling requests" do
  def readBinaryRequest(binary_path)
    File.open(File.dirname(__FILE__) + '/fixtures/request/' + binary_path).read
  end

  it "should handle remoting message from remote object" do
    input = readBinaryRequest("remotingMessage.bin")
    req = AMF::Request.new.populate_from_stream(input)

    expected = [{
      :timeToLive => 0,
      :body => [true],
      :timestamp => 0,
      :source => "WritesController",
      :destination => "rubyamf",
      :operation => "save",
      :headers => {:DSEndpoint => nil, :DSId => "nil"},
      :messageId => "FE4AF2BC-DD3C-5470-05D8-9971D51FF89D",
      :clientId => nil
    }]
    req.messages[0].data.should == expected
  end

  it "should handle command message from remote object" do
    input = readBinaryRequest("commandMessage.bin")
    req = AMF::Request.new.populate_from_stream(input)

    expected = [{
      :correlationId => "",
      :destination => "",
      :operation => 5,
      :body => {},
      :headers => {:DSMessagingVersion => 1, :DSId => "nil"},
      :timeToLive => 0,
      :messageId => "7B0ACE15-8D57-6AE5-B9D4-99C2D32C8246",
      :timestamp => 0,
      :clientId => nil
    }]
    req.messages[0].data.should == expected
  end
end

describe "when handling responses" do
end