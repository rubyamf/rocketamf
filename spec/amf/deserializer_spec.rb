require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "when deserializing" do
  #File Utilities
  def readBinaryObject(binary_path)
    File.open(File.dirname(__FILE__) + '/../fixtures/objects/' + binary_path).read
  end

  describe "AMF0" do
    it "should deserialize numbers" do
      input = readBinaryObject('amf0-number.bin')
      output = AMF.deserialize(input, 0)
      output.should == 3.5
    end

    it "should deserialize booleans" do
      input = readBinaryObject('amf0-boolean.bin')
      output = AMF.deserialize(input, 0)
      output.should === true
    end

    it "should deserialize strings" do
      input = readBinaryObject('amf0-string.bin')
      output = AMF.deserialize(input, 0)
      output.should == "this is a テスト"
    end

    it "should deserialize anonymous objects" do
      input = readBinaryObject('amf0-object.bin')
      output = AMF.deserialize(input, 0)
      output.should == {:foo => 'baz', :bar => 3.14}
    end

    it "should deserialize nulls" do
      input = readBinaryObject('amf0-null.bin')
      output = AMF.deserialize(input, 0)
      output.should == nil
    end

    it "should deserialize undefineds" do
      input = readBinaryObject('amf0-undefined.bin')
      output = AMF.deserialize(input, 0)
      output.should == nil
    end

    it "should deserialize references properly" do
      input = readBinaryObject('amf0-ref-test.bin')
      output = AMF.deserialize(input, 0)
      output.length.should == 2
      output[0].should === output[1]
    end

    it "should deserialize hashes" do
      input = readBinaryObject('amf0-hash.bin')
      output = AMF.deserialize(input, 0)
      output.should == {:a => 'b', :c => 'd'}
    end

    it "should deserialize arrays from flash player" do
      # Even Array is serialized as a "hash", so check that deserializer converts to array
      input = readBinaryObject('amf0-ecma-ordinal-array.bin')
      output = AMF.deserialize(input, 0)
      output.should == ['a', 'b', 'c', 'd']
    end

    it "should deserialize dates" do
      input = readBinaryObject('amf0-date.bin')
      output = AMF.deserialize(input, 0)
      output.should == Time.utc(2003, 2, 13, 5)
    end

    it "should deserialize an unmapped object as a dynamic anonymous object" do
      input = readBinaryObject("amf0-typed-object.bin")
      output = AMF.deserialize(input, 0)

      output.type.should == 'org.rackAMF.ASClass'
      output.should == {:foo => 'bar', :baz => nil}
    end

    it "should deserialize a mapped object as a mapped ruby class instance" do
      class RubyClass
        attr_accessor :foo, :baz
      end
      AMF::ClassMapper.define {|m| m.map :as => 'org.rackAMF.ASClass', :ruby => 'RubyClass'}

      input = readBinaryObject("amf0-typed-object.bin")
      output = AMF.deserialize(input, 0)

      output.should be_a(RubyClass)
      output.foo.should == 'bar'
      output.baz.should == nil
    end
  end

  describe "AMF3" do
    describe "simple messages" do
      it "should deserialize a null" do
        input = readBinaryObject("amf3-null.bin")
        output = AMF.deserialize(input, 3)
        output.should == nil
      end

      it "should deserialize a false" do
        input = readBinaryObject("amf3-false.bin")
        output = AMF.deserialize(input, 3)
        output.should == false
      end

      it "should deserialize a true" do
        input = readBinaryObject("amf3-true.bin")
        output = AMF.deserialize(input, 3)
        output.should == true
      end

      it "should deserialize integers" do
        input = readBinaryObject("amf3-max.bin")
        output = AMF.deserialize(input, 3)
        output.should == AMF::MAX_INTEGER

        input = readBinaryObject("amf3-0.bin")
        output = AMF.deserialize(input, 3)
        output.should == 0

        input = readBinaryObject("amf3-min.bin")
        output = AMF.deserialize(input, 3)
        output.should == AMF::MIN_INTEGER
      end

      it "should deserialize large integers" do
        input = readBinaryObject("amf3-largeMax.bin")
        output = AMF.deserialize(input, 3)
        output.should == AMF::MAX_INTEGER + 1

        input = readBinaryObject("amf3-largeMin.bin")
        output = AMF.deserialize(input, 3)
        output.should == AMF::MIN_INTEGER - 1
      end

      it "should deserialize BigNums" do
        input = readBinaryObject("amf3-bigNum.bin")
        output = AMF.deserialize(input, 3)
        output.should == 2**1000
      end

      it "should deserialize a simple string" do
        input = readBinaryObject("amf3-string.bin")
        output = AMF.deserialize(input, 3)
        output.should == "String . String"
      end

      it "should deserialize a symbol as a string" do
        input = readBinaryObject("amf3-symbol.bin")
        output = AMF.deserialize(input, 3)
        output.should == "foo"
      end

      it "should deserialize dates" do
        input = readBinaryObject("amf3-date.bin")
        output = AMF.deserialize(input, 3)
        output.should == Time.at(0)
      end

      #BAH! Who sends XML over AMF?
      it "should deserialize a REXML document"
    end

    describe "objects" do
      it "should deserialize an unmapped object as a dynamic anonymous object" do
        input = readBinaryObject("amf3-dynObject.bin")
        output = AMF.deserialize(input, 3)

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

        input = readBinaryObject("amf3-typedObject.bin")
        output = AMF.deserialize(input, 3)

        output.should be_a(RubyClass)
        output.foo.should == 'bar'
        output.baz.should == nil
      end

      it "should deserialize a hash as a dynamic anonymous object" do
        input = readBinaryObject("amf3-hash.bin")
        output = AMF.deserialize(input, 3)
        output.should == {:foo => "bar", :answer => 42}
      end

      it "should deserialize an open struct as a dynamic anonymous object"

      it "should deserialize an empty array" do
        input = readBinaryObject("amf3-emptyArray.bin")
        output = AMF.deserialize(input, 3)
        output.should == []
      end

      it "should deserialize an array of primatives" do
        input = readBinaryObject("amf3-primArray.bin")
        output = AMF.deserialize(input, 3)
        output.should == [1,2,3,4,5]
      end

      it "should deserialize an array of mixed objects" do
        input = readBinaryObject("amf3-mixedArray.bin")
        output = AMF.deserialize(input, 3)

        h1 = {:foo_one => "bar_one"}
        h2 = {:foo_two => ""}
        so1 = {:foo_three => 42}
        output.should == [h1, h2, so1, {:foo_three => nil}, {}, [h1, h2, so1], [], 42, "", [], "", {}, "bar_one", so1]
      end

      it "should deserialize a byte array"
    end

    describe "and implementing the AMF Spec" do
      it "should keep references of duplicate strings" do
        input = readBinaryObject("amf3-stringRef.bin")
        output = AMF.deserialize(input, 3)

        class StringCarrier; attr_accessor :str; end
        foo = "foo"
        bar = "str"
        sc = StringCarrier.new
        sc = {:str => foo}
        output.should == [foo, bar, foo, bar, foo, sc]
      end

      it "should not reference the empty string" do
        input = readBinaryObject("amf3-emptyStringRef.bin")
        output = AMF.deserialize(input, 3)
        output.should == ["",""]
      end

      it "should keep references of duplicate dates" do
        input = readBinaryObject("amf3-datesRef.bin")
        output = AMF.deserialize(input, 3)

        output[0].should equal(output[1])
        # Expected object:
        # [DateTime.parse "1/1/1970", DateTime.parse "1/1/1970"]
      end

      it "should keep reference of duplicate objects" do
        input = readBinaryObject("amf3-objRef.bin")
        output = AMF.deserialize(input, 3)

        obj1 = {:foo => "bar"}
        obj2 = {:foo => obj1[:foo]}
        output.should == [[obj1, obj2], "bar", [obj1, obj2]]
      end

      it "should keep references of duplicate arrays" do
        input = readBinaryObject("amf3-arrayRef.bin")
        output = AMF.deserialize(input, 3)

        a = [1,2,3]
        b = %w{ a b c }
        output.should == [a, b, a, b]
      end

      it "should not keep references of duplicate empty arrays unless the object_id matches" do
        input = readBinaryObject("amf3-emptyArrayRef.bin")
        output = AMF.deserialize(input, 3)

        a = []
        b = []
        output.should == [a,b,a,b]
      end

      it "should keep references of duplicate XML and XMLDocuments"
      it "should keep references of duplicate byte arrays"

      it "should deserialize a deep object graph with circular references" do
        input = readBinaryObject("amf3-graphMember.bin")
        output = AMF.deserialize(input, 3)

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
  end
end