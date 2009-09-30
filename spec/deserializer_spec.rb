require File.dirname(__FILE__) + '/spec_helper.rb'

describe "AMF when deserializing" do
  #File Utilities
  def readBinaryObject(binary_path)
    File.open(File.dirname(__FILE__) + '/fixtures/objects/' + binary_path).read
  end

  def readBinaryRequest(binary_path)
    File.open(File.dirname(__FILE__) + '/fixtures/request/' + binary_path).read
  end

  describe "simple messages" do
    it "should deserialize a null" do
      input = readBinaryObject("null.bin")
      output = AMF.deserialize(input)
      output.should == nil
    end

    it "should deserialize a false" do
      input = readBinaryObject("false.bin")
      output = AMF.deserialize(input)
      output.should == false
    end

    it "should deserialize a true" do
      input = readBinaryObject("true.bin")
      output = AMF.deserialize(input)
      output.should == true
    end

    it "should deserialize integers" do
      input = readBinaryObject("max.bin")
      output = AMF.deserialize(input)
      output.should == AMF::MAX_INTEGER

      input = readBinaryObject("0.bin")
      output = AMF.deserialize(input)
      output.should == 0

      input = readBinaryObject("min.bin")
      output = AMF.deserialize(input)
      output.should == AMF::MIN_INTEGER
    end

    it "should deserialize large integers" do
      input = readBinaryObject("largeMax.bin")
      output = AMF.deserialize(input)
      output.should == AMF::MAX_INTEGER + 1

      input = readBinaryObject("largeMin.bin")
      output = AMF.deserialize(input)
      output.should == AMF::MIN_INTEGER - 1
    end

    it "should deserialize BigNums" do
      input = readBinaryObject("bigNum.bin")
      output = AMF.deserialize(input)
      output.should == 2**1000
    end

    it "should deserialize a simple string" do
      input = readBinaryObject("string.bin")
      output = AMF.deserialize(input)
      output.should == "String . String"
    end

    it "should deserialize a symbol as a string" do
      input = readBinaryObject("symbol.bin")
      output = AMF.deserialize(input)
      output.should == "foo"
    end

    it "should deserialize DateTimes" do
      input = readBinaryObject("date.bin")
      output = AMF.deserialize(input)
      output.should == DateTime.parse("1/1/1970")
    end

    #BAH! Who sends XML over AMF?
    it "should deserialize a REXML document"
  end

  describe "objects" do
    it "should deserialize an unmapped object as a dynamic anonymous object" do
      input = readBinaryObject("dynObject.bin")
      output = AMF.deserialize(input)

      expected = {
        :property_one => 'foo',
        :property_two => 1,
        :nil_property => nil,
        :another_public_property => 'a_public_value'
      }
      output.should == expected
    end

    it "should deserialize a mapped object as a mapped ruby class instance" do
      class RubyClass
        attr_accessor :foo, :baz
      end
      AMF::ClassMapper.define {|m| m.map :as => 'org.rackAMF.ASClass', :ruby => 'RubyClass'}

      input = readBinaryObject('typedObject.bin')
      output = AMF.deserialize(input)

      output.should be_a(RubyClass)
      output.foo.should == 'bar'
      output.baz.should == nil
    end

    it "should deserialize a hash as a dynamic anonymous object" do
      input = readBinaryObject("hash.bin")
      output = AMF.deserialize(input)
      output.should == {:foo => "bar", :answer => 42}
    end

    it "should deserialize an open struct as a dynamic anonymous object"

    it "should deserialize an empty array" do
      input = readBinaryObject("emptyArray.bin")
      output = AMF.deserialize(input)
      output.should == []
    end

    it "should deserialize an array of primatives" do
      input = readBinaryObject("primArray.bin")
      output = AMF.deserialize(input)
      output.should == [1,2,3,4,5]
    end

    it "should deserialize an array of mixed objects" do
      input = readBinaryObject("mixedArray.bin")
      output = AMF.deserialize(input)

      h1 = {:foo_one => "bar_one"}
      h2 = {:foo_two => ""}
      so1 = {:foo_three => 42}
      output.should == [h1, h2, so1, {:foo_three => nil}, {}, [h1, h2, so1], [], 42, "", [], "", {}, "bar_one", so1]
    end

    it "should deserialize a byte array"
  end

  describe "and implementing the AMF Spec" do
    it "should keep references of duplicate strings" do
      input = readBinaryObject("stringRef.bin")
      output = AMF.deserialize(input)

      class StringCarrier; attr_accessor :str; end
      foo = "foo"
      bar = "str"
      sc = StringCarrier.new
      sc = {:str => foo}
      output.should == [foo, bar, foo, bar, foo, sc]
    end

    it "should not reference the empty string" do
      input = readBinaryObject("emptyStringRef.bin")
      output = AMF.deserialize(input)
      output.should == ["",""]
    end

    it "should keep references of duplicate dates" do
      input = readBinaryObject("datesRef.bin")
      output = AMF.deserialize(input)

      output[0].should equal(output[1])
      # Expected object:
      # [DateTime.parse "1/1/1970", DateTime.parse "1/1/1970"]
    end

    it "should keep reference of duplicate objects" do
      input = readBinaryObject("objRef.bin")
      output = AMF.deserialize(input)

      obj1 = {:foo => "bar"}
      obj2 = {:foo => obj1[:foo]}
      output.should == [[obj1, obj2], "bar", [obj1, obj2]]
    end

    it "should keep references of duplicate arrays" do
      input = readBinaryObject("arrayRef.bin")
      output = AMF.deserialize(input)

      a = [1,2,3]
      b = %w{ a b c }
      output.should == [a, b, a, b]
    end

    it "should not keep references of duplicate empty arrays unless the object_id matches" do
      input = readBinaryObject("emptyArrayRef.bin")
      output = AMF.deserialize(input)

      a = []
      b = []
      output.should == [a,b,a,b]
    end

    it "should keep references of duplicate XML and XMLDocuments"
    it "should keep references of duplicate byte arrays"

    it "should deserialize a deep object graph with circular references" do
      input = readBinaryObject("graphMember.bin")
      output = AMF.deserialize(input)

      output[:children][0][:parent].should === output
      output[:parent].should === nil
      output[:children].length.should == 2
      # Expected object:
      # parent = Hash.new
      # child1 = Hash.new
      # child1[:parent] = parent
      # child1[:children] = []
      # child2 = Hash.new
      # child2[:parent] = parent
      # child2[:children] = []
      # parent[:parent] = nil
      # parent[:children] = [child1, child2]
    end
  end

  describe "request" do
    it "should handle remoting message from remote object" do
      input = readBinaryRequest("remotingMessage.bin")
      output = AMF.deserializer.new().deserialize_request(input)

      expected = {
        :timeToLive => 0,
        :body => [true],
        :timestamp => 0,
        :source => "WritesController",
        :destination => "rubyamf",
        :operation => "save",
        :headers => {:DSEndpoint => nil, :DSId => "nil"},
        :messageId => "FE4AF2BC-DD3C-5470-05D8-9971D51FF89D",
        :clientId => nil
      }
      output.bodies[0].data.should == expected
    end

    it "should handle command message from remote object" do
      input = readBinaryRequest("commandMessage.bin")
      output = AMF.deserializer.new().deserialize_request(input)

      expected = {
        :correlationId => "",
        :destination => "",
        :operation => 5,
        :body => {},
        :headers => {:DSMessagingVersion => 1, :DSId => "nil"},
        :timeToLive => 0,
        :messageId => "7B0ACE15-8D57-6AE5-B9D4-99C2D32C8246",
        :timestamp => 0,
        :clientId => nil
      }
      output.bodies[0].data.should == expected
    end
  end
end