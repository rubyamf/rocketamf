require File.dirname(__FILE__) + '/spec_helper.rb'

require 'rexml/document'

describe "when serializing" do
  describe "AMF3" do
    def readBinaryObject(binary_path)
      File.open('spec/fixtures/objects/' + binary_path).read
    end

    describe "simple messages" do
      it "should serialize a null" do
        expected = readBinaryObject("amf3-null.bin")
        output = AMF.serialize(nil, 3)
        output.should == expected
      end

      it "should serialize a false" do
        expected = readBinaryObject("amf3-false.bin")
        output = AMF.serialize(false, 3)
        output.should == expected
      end

      it "should serialize a true" do
        expected = readBinaryObject("amf3-true.bin")
        output = AMF.serialize(true, 3)
        output.should == expected
      end

      it "should serialize integers" do
        expected = readBinaryObject("amf3-max.bin")
        input = AMF::MAX_INTEGER
        output = AMF.serialize(input, 3)
        output.should == expected

        expected = readBinaryObject("amf3-0.bin")
        output = AMF.serialize(0, 3)
        output.should == expected

        expected = readBinaryObject("amf3-min.bin")
        input = AMF::MIN_INTEGER
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize large integers" do
        expected = readBinaryObject("amf3-largeMax.bin")
        input = AMF::MAX_INTEGER + 1
        output = AMF.serialize(input, 3)
        output.should == expected

        expected = readBinaryObject("amf3-largeMin.bin")
        input = AMF::MIN_INTEGER - 1
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize BigNums" do
        expected = readBinaryObject("amf3-bigNum.bin")
        input = 2**1000
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a simple string" do
        expected = readBinaryObject("amf3-string.bin")
        input = "String . String"
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a symbol as a string" do
        expected = readBinaryObject("amf3-symbol.bin")
        output = AMF.serialize(:foo, 3)
        output.should == expected
      end

      it "should serialize Times" do
        expected = readBinaryObject("amf3-date.bin")
        input = Time.utc 1970, 1, 1, 0
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      #BAH! Who sends XML over AMF?
      it "should serialize a REXML document"
    end

    describe "objects" do
      it "should serialize an unmapped object as a dynamic anonymous object" do
        class NonMappedObject
          attr_accessor :property_one
          attr_accessor :property_two
          attr_accessor :nil_property
          attr_writer :read_only_prop

          def another_public_property
            'a_public_value'
          end

          def method_with_arg arg='foo'
            arg
          end
        end
        obj = NonMappedObject.new
        obj.property_one = 'foo'
        obj.property_two = 1
        obj.nil_property = nil

        expected = readBinaryObject("amf3-dynObject.bin")
        input = obj
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a hash as a dynamic anonymous object" do
        hash = {}
        hash[:answer] = 42
        hash[:foo] = "bar"

        expected = readBinaryObject("amf3-hash.bin")
        input = hash
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize an open struct as a dynamic anonymous object"

      it "should serialize an empty array" do
        expected = readBinaryObject("amf3-emptyArray.bin")
        input = []
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize an array of primatives" do
        expected = readBinaryObject("amf3-primArray.bin")
        input = [1, 2, 3, 4, 5]
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize an array of mixed objects" do
        h1 = {:foo_one => "bar_one"}
        h2 = {:foo_two => ""}
        class SimpleObj
          attr_accessor :foo_three
        end
        so1 = SimpleObj.new
        so1.foo_three = 42

        expected = readBinaryObject("amf3-mixedArray.bin")
        input = [h1, h2, so1, SimpleObj.new, {}, [h1, h2, so1], [], 42, "", [], "", {}, "bar_one", so1]
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a byte array"
    end

    describe "and implementing the AMF Spec" do
      it "should keep references of duplicate strings" do
        class StringCarrier
          attr_accessor :str
        end
        foo = "foo"
        bar = "str"
        sc = StringCarrier.new
        sc.str = foo

        expected = readBinaryObject("amf3-stringRef.bin")
        input = [foo, bar, foo, bar, foo, sc]
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should not reference the empty string" do
        expected = readBinaryObject("amf3-emptyStringRef.bin")
        input = ""
        output = AMF.serialize([input,input], 3)
        output.should == expected
      end

      it "should keep references of duplicate dates" do
        expected = readBinaryObject("amf3-datesRef.bin")
        input = Time.utc 1970, 1, 1, 0
        output = AMF.serialize([input,input], 3)
        output.should == expected
      end

      it "should keep reference of duplicate objects" do
        class SimpleReferenceableObj
          attr_accessor :foo
        end
        obj1 = SimpleReferenceableObj.new
        obj1.foo = :bar
        obj2 = SimpleReferenceableObj.new
        obj2.foo = obj1.foo

        expected = readBinaryObject("amf3-objRef.bin")
        input = [[obj1, obj2], "bar", [obj1, obj2]]
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should keep references of duplicate arrays" do
        a = [1,2,3]
        b = %w{ a b c }

        expected = readBinaryObject("amf3-arrayRef.bin")
        input = [a, b, a, b]
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should not keep references of duplicate empty arrays unless the object_id matches" do
        a = []
        b = []
        a.should == b
        a.object_id.should_not == b.object_id

        expected = readBinaryObject("amf3-emptyArrayRef.bin")
        input = [a,b,a,b]
        output = AMF.serialize(input, 3)
        output.should == expected
      end

      it "should keep references of duplicate XML and XMLDocuments"
      it "should keep references of duplicate byte arrays"

      it "should serialize a deep object graph with circular references" do
        class GraphMember
          attr_accessor :parent
          attr_accessor :children

          def initialize
            self.children = []
          end

          def add_child child
            children << child
            child.parent = self
            child
          end
        end

        parent = GraphMember.new
        level_1_child_1 = parent.add_child GraphMember.new
        level_1_child_2 = parent.add_child GraphMember.new

        expected = readBinaryObject("amf3-graphMember.bin")
        input = parent
        output = AMF.serialize(input, 3)
        output.should == expected
      end
    end
  end
end