require "spec_helper.rb"

describe RocketAMF::Values::ArrayCollection do
  it "should deserialize properly" do
    input = object_fixture("amf3-arrayCollection.bin")
    output = RocketAMF.deserialize(input, 3)

    output.should be_a(RocketAMF::Values::ArrayCollection)
    output.should == ["foo", "bar"]
  end

  it "should serialize properly" do
    expected = object_fixture('amf3-arrayCollection.bin')
    input = RocketAMF::Values::ArrayCollection.new
    input.push("foo", "bar")
    output = RocketAMF.serialize(input, 3)
    output.should == expected
  end
end