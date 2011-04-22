# encoding: UTF-8

require "spec_helper.rb"
require 'rexml/document'

describe "when serializing" do
  before :each do
    RocketAMF::ClassMapper.reset
  end

  it "should raise exception with invalid version number" do
    lambda {
      RocketAMF.serialize("", 5)
    }.should raise_error("unsupported version 5")
  end

  describe "AMF0" do
    it "should serialize nils" do
      output = RocketAMF.serialize(nil, 0)
      output.should == object_fixture('amf0-null.bin')
    end

    it "should serialize booleans" do
      output = RocketAMF.serialize(true, 0)
      output.should === object_fixture('amf0-boolean.bin')
    end

    it "should serialize numbers" do
      output = RocketAMF.serialize(3.5, 0)
      output.should == object_fixture('amf0-number.bin')
    end

    it "should serialize strings" do
      output = RocketAMF.serialize("this is a テスト", 0)
      output.should == object_fixture('amf0-string.bin')
    end

    it "should serialize frozen strings" do
      output = RocketAMF.serialize("this is a テスト".freeze, 0)
      output.should == object_fixture('amf0-string.bin')
    end

    it "should serialize arrays" do
      output = RocketAMF.serialize(['a', 'b', 'c', 'd'], 0)
      output.should == object_fixture('amf0-strict-array.bin')
    end

    it "should serialize references" do
      obj = OtherClass.new
      obj.foo = "baz"
      obj.bar = 3.14

      output = RocketAMF.serialize({'0' => obj, '1' => obj}, 0)
      output.should == object_fixture('amf0-ref-test.bin')
    end

    it "should serialize Time objects" do
      output = RocketAMF.serialize(Time.utc(2003, 2, 13, 5), 0)
      output.should == object_fixture('amf0-time.bin')
    end

    it "should serialize Date objects" do
      output = RocketAMF.serialize(Date.civil(2020, 5, 30), 0)
      output.should == object_fixture('amf0-date.bin')
    end

    it "should serialize DateTime objects" do
      output = RocketAMF.serialize(DateTime.civil(2003, 2, 13, 5), 0)
      output.should == object_fixture('amf0-time.bin')
    end

    it "should serialize hashes as objects" do
      output = RocketAMF.serialize({:baz => nil, "foo" => "bar"}, 0)
      output.should == object_fixture('amf0-untyped-object.bin')
    end

    it "should serialize unmapped objects" do
      obj = RubyClass.new
      obj.foo = "bar"

      output = RocketAMF.serialize(obj, 0)
      output.should == object_fixture('amf0-untyped-object.bin')
    end

    it "should serialize mapped objects" do
      obj = RubyClass.new
      obj.foo = "bar"
      RocketAMF::ClassMapper.define {|m| m.map :as => 'org.rocketAMF.ASClass', :ruby => 'RubyClass'}

      output = RocketAMF.serialize(obj, 0)
      output.should == object_fixture('amf0-typed-object.bin')
    end

    if "".respond_to?(:force_encoding)
      it "should support multiple encodings" do
        shift_str = "\x53\x68\x69\x66\x74\x20\x83\x65\x83\x58\x83\x67".force_encoding("Shift_JIS") # "Shift テスト"
        utf_str = "\x55\x54\x46\x20\xe3\x83\x86\xe3\x82\xb9\xe3\x83\x88".force_encoding("UTF-8") # "UTF テスト"
        output = RocketAMF.serialize({"0" => 5, "1" => shift_str, "2" => utf_str, "3" => 5}, 0)
        output.should == object_fixture("amf0-complexEncodedStringArray.bin")
      end
    end
  end

  describe "AMF3" do
    describe "simple messages" do
      it "should serialize a null" do
        expected = object_fixture("amf3-null.bin")
        output = RocketAMF.serialize(nil, 3)
        output.should == expected
      end

      it "should serialize a false" do
        expected = object_fixture("amf3-false.bin")
        output = RocketAMF.serialize(false, 3)
        output.should == expected
      end

      it "should serialize a true" do
        expected = object_fixture("amf3-true.bin")
        output = RocketAMF.serialize(true, 3)
        output.should == expected
      end

      it "should serialize integers" do
        expected = object_fixture("amf3-max.bin")
        input = RocketAMF::MAX_INTEGER
        output = RocketAMF.serialize(input, 3)
        output.should == expected

        expected = object_fixture("amf3-0.bin")
        output = RocketAMF.serialize(0, 3)
        output.should == expected

        expected = object_fixture("amf3-min.bin")
        input = RocketAMF::MIN_INTEGER
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize large integers" do
        expected = object_fixture("amf3-largeMax.bin")
        input = RocketAMF::MAX_INTEGER + 1
        output = RocketAMF.serialize(input, 3)
        output.should == expected

        expected = object_fixture("amf3-largeMin.bin")
        input = RocketAMF::MIN_INTEGER - 1
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize floats" do
        expected = object_fixture("amf3-float.bin")
        input = 3.5
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize BigNums" do
        expected = object_fixture("amf3-bigNum.bin")
        input = 2**1000
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a simple string" do
        expected = object_fixture("amf3-string.bin")
        input = "String . String"
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a frozen string" do
        expected = object_fixture("amf3-string.bin")
        input = "String . String".freeze
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a symbol as a string" do
        expected = object_fixture("amf3-symbol.bin")
        output = RocketAMF.serialize(:foo, 3)
        output.should == expected
      end

      it "should serialize Time objects" do
        expected = object_fixture("amf3-date.bin")
        input = Time.utc 1970, 1, 1, 0
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize Date objects" do
        expected = object_fixture("amf3-date.bin")
        input = Date.civil 1970, 1, 1, 0
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize DateTime objects" do
        expected = object_fixture("amf3-date.bin")
        input = DateTime.civil 1970, 1, 1, 0
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end
    end

    describe "objects" do
      it "should serialize an unmapped object as a dynamic anonymous object" do
        class NonMappedObject
          def another_public_property
            'a_public_value'
          end

          attr_accessor :nil_property
          attr_accessor :property_one
          attr_accessor :property_two
          attr_writer :read_only_prop

          def method_with_arg arg='foo'
            arg
          end
        end
        obj = NonMappedObject.new
        obj.property_one = 'foo'
        obj.property_two = 1
        obj.nil_property = nil

        expected = object_fixture("amf3-dynObject.bin")
        input = obj
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize externalizable objects" do
        a = ExternalizableTest.new
        a.one = 5
        a.two = 7
        b = ExternalizableTest.new
        b.one = 13
        b.two = 5
        obj = [a, b]

        expected = object_fixture("amf3-externalizable.bin")
        input = obj
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a hash as a dynamic anonymous object" do
        hash = {}
        hash[:answer] = 42
        hash['foo'] = "bar"

        expected = object_fixture("amf3-hash.bin")
        input = hash
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize an empty array" do
        expected = object_fixture("amf3-emptyArray.bin")
        input = []
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize an array of primatives" do
        expected = object_fixture("amf3-primArray.bin")
        input = [1, 2, 3, 4, 5]
        output = RocketAMF.serialize(input, 3)
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

        expected = object_fixture("amf3-mixedArray.bin")
        input = [h1, h2, so1, SimpleObj.new, {}, [h1, h2, so1], [], 42, "", [], "", {}, "bar_one", so1]
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize an array as an array collection" do
        expected = object_fixture('amf3-arrayCollection.bin')

        # Test global
        RocketAMF::ClassMapper.use_array_collection = true
        input = ["foo", "bar"]
        output = RocketAMF.serialize(input, 3)
        output.should == expected
        RocketAMF::ClassMapper.use_array_collection = false

        # Test override
        input = ["foo", "bar"]
        input.is_array_collection = true
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a complex set of array collections" do
        expected = object_fixture('amf3-complexArrayCollection.bin')

        a = ["foo", "bar"]
        a.is_array_collection = true
        b = ["bar", "foo"]
        b.is_array_collection = true
        input = [a, b, b]

        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a byte array" do
        expected = object_fixture("amf3-byteArray.bin")
        input = StringIO.new "\000\003これtest\100"
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end
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

        expected = object_fixture("amf3-stringRef.bin")
        input = [foo, bar, foo, bar, foo, sc]
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should not reference the empty string" do
        expected = object_fixture("amf3-emptyStringRef.bin")
        input = ""
        output = RocketAMF.serialize([input,input], 3)
        output.should == expected
      end

      it "should keep references of duplicate dates" do
        expected = object_fixture("amf3-datesRef.bin")
        input = Time.utc 1970, 1, 1, 0
        output = RocketAMF.serialize([input,input], 3)
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

        expected = object_fixture("amf3-objRef.bin")
        input = [[obj1, obj2], "bar", [obj1, obj2]]
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should keep reference of duplicate object traits" do
        obj1 = RubyClass.new
        obj1.foo = "foo"
        def obj1.encode_amf serializer
          serializer.write_object(self, nil, {:class_name => 'org.rocketAMF.ASClass', :dynamic => false, :externalizable => false, :members => ["baz", "foo"]})
        end
        obj2 = RubyClass.new
        obj2.foo = "bar"
        def obj2.encode_amf serializer
          serializer.write_object(self, nil, {:class_name => 'org.rocketAMF.ASClass', :dynamic => false, :externalizable => false, :members => ["baz", "foo"]})
        end
        input = [obj1, obj2]

        expected = object_fixture("amf3-traitRef.bin")
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should keep references of duplicate arrays" do
        a = [1,2,3]
        b = %w{ a b c }

        expected = object_fixture("amf3-arrayRef.bin")
        input = [a, b, a, b]
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should not keep references of duplicate empty arrays unless the object_id matches" do
        a = []
        b = []
        a.should == b
        a.object_id.should_not == b.object_id

        expected = object_fixture("amf3-emptyArrayRef.bin")
        input = [a,b,a,b]
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should keep references of duplicate byte arrays" do
        b = StringIO.new "ASDF"

        expected = object_fixture("amf3-byteArrayRef.bin")
        input = [b, b]
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a deep object graph with circular references" do
        class GraphMember
          attr_accessor :children
          attr_accessor :parent

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

        expected = object_fixture("amf3-graphMember.bin")
        input = parent
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end
    end

    if "".respond_to?(:force_encoding)
      describe "and handling encodings" do
        it "should support multiple encodings" do
          shift_str = "\x53\x68\x69\x66\x74\x20\x83\x65\x83\x58\x83\x67".force_encoding("Shift_JIS") # "Shift テスト"
          utf_str = "\x55\x54\x46\x20\xe3\x83\x86\xe3\x82\xb9\xe3\x83\x88".force_encoding("UTF-8") # "UTF テスト"
          output = RocketAMF.serialize([5, shift_str, utf_str, 5], 3)
          output.should == object_fixture("amf3-complexEncodedStringArray.bin")
        end

        it "should keep references of duplicate strings with different encodings" do
          # String is "this is a テスト"
          shift_str = "\x74\x68\x69\x73\x20\x69\x73\x20\x61\x20\x83\x65\x83\x58\x83\x67".force_encoding("Shift_JIS")
          utf_str   = "\x74\x68\x69\x73\x20\x69\x73\x20\x61\x20\xe3\x83\x86\xe3\x82\xb9\xe3\x83\x88".force_encoding("UTF-8")

          expected = object_fixture("amf3-encodedStringRef.bin")
          output = RocketAMF.serialize([shift_str, utf_str], 3)
          output.should == expected
        end

        it "should handle inappropriate UTF-8 characters in byte arrays" do
          str = "\xff\xff\xff".force_encoding("ASCII-8BIT")
          str.freeze # For added amusement
          output = RocketAMF.serialize(StringIO.new(str), 3)
          output.should == "\x0c\x07\xff\xff\xff".force_encoding("ASCII-8BIT")
        end
      end
    end
  end
end