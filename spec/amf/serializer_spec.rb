require File.dirname(__FILE__) + '/../spec_helper.rb'

require 'rexml/document'

describe "when serializing" do
  before :each do
    RocketAMF::ClassMapper.reset
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

    it "should serialize arrays" do
      output = RocketAMF.serialize(['a', 'b', 'c', 'd'], 0)
      output.should == object_fixture('amf0-strict-array.bin')
    end

    it "should serialize references" do
      class OtherClass
        attr_accessor :foo, :bar
      end
      obj = OtherClass.new
      obj.foo = "baz"
      obj.bar = 3.14

      output = RocketAMF.serialize({'0' => obj, '1' => obj}, 0)
      output.should == object_fixture('amf0-ref-test.bin')
    end

    it "should serialize dates" do
      output = RocketAMF.serialize(Time.utc(2003, 2, 13, 5), 0)
      output.should == object_fixture('amf0-date.bin')
    end
  
    it "should serialize hashes" do
      output = RocketAMF.serialize({:a => 'b', :c => 'd'}, 0)
      output.should == object_fixture('amf0-hash.bin')
    end

    it "should serialize unmapped objects" do
      class RubyClass
        attr_accessor :foo, :baz
      end
      obj = RubyClass.new
      obj.foo = "bar"

      output = RocketAMF.serialize(obj, 0)
      output.should == object_fixture('amf0-untyped-object.bin')
    end

    it "should serialize mapped objects" do
      class RubyClass
        attr_accessor :foo, :baz
      end
      obj = RubyClass.new
      obj.foo = "bar"
      RocketAMF::ClassMapper.define {|m| m.map :as => 'org.rocketAMF.ASClass', :ruby => 'RubyClass'}

      output = RocketAMF.serialize(obj, 0)
      output.should == object_fixture('amf0-typed-object.bin')
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

      it "should serialize a symbol as a string" do
        expected = object_fixture("amf3-symbol.bin")
        output = RocketAMF.serialize(:foo, 3)
        output.should == expected
      end

      it "should serialize Times" do
        expected = object_fixture("amf3-date.bin")
        input = Time.utc 1970, 1, 1, 0
        output = RocketAMF.serialize(input, 3)
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

        expected = object_fixture("amf3-dynObject.bin")
        input = obj
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end

      it "should serialize a hash as a dynamic anonymous object" do
        hash = {}
        hash[:answer] = 42
        hash[:foo] = "bar"

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

        expected = object_fixture("amf3-graphMember.bin")
        input = parent
        output = RocketAMF.serialize(input, 3)
        output.should == expected
      end
    end
  end
end