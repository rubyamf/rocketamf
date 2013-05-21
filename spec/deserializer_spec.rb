# encoding: UTF-8

require "spec_helper.rb"

describe "when deserializing" do
  before :each do
    RocketAMF::ClassMapper.reset
  end

  it "should raise exception with invalid version number" do
    lambda {
      RocketAMF.deserialize("", 5)
    }.should raise_error("unsupported version 5")
  end

  describe "AMF0" do
    it "should update source pos if source is a StringIO object" do
      input = StringIO.new(object_fixture('amf0-number.bin'))
      input.pos.should == 0
      output = RocketAMF.deserialize(input, 0)
      input.pos.should == 9
    end

    it "should deserialize numbers" do
      input = object_fixture('amf0-number.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should == 3.5
    end

    it "should deserialize booleans" do
      input = object_fixture('amf0-boolean.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should === true
    end

    it "should deserialize UTF8 strings" do
      input = object_fixture('amf0-string.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should == "this is a テスト"
    end

    it "should deserialize nulls" do
      input = object_fixture('amf0-null.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should == nil
    end

    it "should deserialize undefineds" do
      input = object_fixture('amf0-undefined.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should == nil
    end

    it "should deserialize hashes" do
      input = object_fixture('amf0-hash.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should == {'a' => 'b', 'c' => 'd'}
    end

    it "should deserialize hashes with empty string keys" do
      input = object_fixture('amf0-empty-string-key-hash.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should == {'a' => 'b', 'c' => 'd', '' => 'last'}
    end

    it "should deserialize arrays from flash player" do
      # Even Array is serialized as a "hash"
      input = object_fixture('amf0-ecma-ordinal-array.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should == {'0' => 'a', '1' => 'b', '2' => 'c', '3' => 'd'}
    end

    it "should deserialize strict arrays" do
      input = object_fixture('amf0-strict-array.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should == ['a', 'b', 'c', 'd']
    end

    it "should deserialize dates" do
      input = object_fixture('amf0-time.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should == Time.utc(2003, 2, 13, 5)
    end

    it "should deserialize an XML document" do
      input = object_fixture('amf0-xml-doc.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should == '<parent><child prop="test" /></parent>'
    end

    it "should deserialize anonymous objects" do
      input = object_fixture('amf0-object.bin')
      output = RocketAMF.deserialize(input, 0)
      output.should == {'foo' => 'baz', 'bar' => 3.14}
      output.type.should == ""
    end

    it "should deserialize an unmapped object as a dynamic anonymous object" do
      input = object_fixture("amf0-typed-object.bin")
      output = RocketAMF.deserialize(input, 0)

      output.type.should == 'org.amf.ASClass'
      output.should == {'foo' => 'bar', 'baz' => nil}
    end

    it "should deserialize a mapped object as a mapped ruby class instance" do
      RocketAMF::ClassMapper.define {|m| m.map :as => 'org.amf.ASClass', :ruby => 'RubyClass'}

      input = object_fixture("amf0-typed-object.bin")
      output = RocketAMF.deserialize(input, 0)

      output.should be_a(RubyClass)
      output.foo.should == 'bar'
      output.baz.should == nil
    end

    it "should deserialize references properly" do
      input = object_fixture('amf0-ref-test.bin')
      output = RocketAMF.deserialize(input, 0)
      output.length.should == 2
      output["0"].should === output["1"]
    end
  end

  describe "AMF3" do
    it "should update source pos if source is a StringIO object" do
      input = StringIO.new(object_fixture('amf3-null.bin'))
      input.pos.should == 0
      output = RocketAMF.deserialize(input, 3)
      input.pos.should == 1
    end

    describe "simple messages" do
      it "should deserialize a null" do
        input = object_fixture("amf3-null.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == nil
      end

      it "should deserialize a false" do
        input = object_fixture("amf3-false.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == false
      end

      it "should deserialize a true" do
        input = object_fixture("amf3-true.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == true
      end

      it "should deserialize integers" do
        input = object_fixture("amf3-max.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == RocketAMF::MAX_INTEGER

        input = object_fixture("amf3-0.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == 0

        input = object_fixture("amf3-min.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == RocketAMF::MIN_INTEGER
      end

      it "should deserialize large integers" do
        input = object_fixture("amf3-large-max.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == RocketAMF::MAX_INTEGER + 1

        input = object_fixture("amf3-large-min.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == RocketAMF::MIN_INTEGER - 1
      end

      it "should deserialize BigNums" do
        input = object_fixture("amf3-bignum.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == 2**1000
      end

      it "should deserialize a simple string" do
        input = object_fixture("amf3-string.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == "String . String"
      end

      it "should deserialize a symbol as a string" do
        input = object_fixture("amf3-symbol.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == "foo"
      end

      it "should deserialize dates" do
        input = object_fixture("amf3-date.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == Time.at(0)
      end

      it "should deserialize XML" do
        # XMLDocument tag
        input = object_fixture("amf3-xml-doc.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == '<parent><child prop="test" /></parent>'

        # XML tag
        input = object_fixture("amf3-xml.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == '<parent><child prop="test"/></parent>'
      end
    end

    describe "objects" do
      it "should deserialize an unmapped object as a dynamic anonymous object" do
        input = object_fixture("amf3-dynamic-object.bin")
        output = RocketAMF.deserialize(input, 3)

        expected = {
          'property_one' => 'foo',
          'nil_property' => nil,
          'another_public_property' => 'a_public_value'
        }
        output.should == expected
        output.type.should == ""
      end

      it "should deserialize a mapped object as a mapped ruby class instance" do
        RocketAMF::ClassMapper.define {|m| m.map :as => 'org.amf.ASClass', :ruby => 'RubyClass'}

        input = object_fixture("amf3-typed-object.bin")
        output = RocketAMF.deserialize(input, 3)

        output.should be_a(RubyClass)
        output.foo.should == 'bar'
        output.baz.should == nil
      end

      it "should deserialize externalizable objects" do
        RocketAMF::ClassMapper.define {|m| m.map :as => 'ExternalizableTest', :ruby => 'ExternalizableTest'}

        input = object_fixture("amf3-externalizable.bin")
        output = RocketAMF.deserialize(input, 3)

        output.length.should == 2
        output[0].one.should == 5
        output[1].two.should == 5
      end

      it "should deserialize a hash as a dynamic anonymous object" do
        input = object_fixture("amf3-hash.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == {'foo' => "bar", 'answer' => 42}
      end

      it "should deserialize an empty array" do
        input = object_fixture("amf3-empty-array.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == []
      end

      it "should deserialize an array of primitives" do
        input = object_fixture("amf3-primitive-array.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == [1,2,3,4,5]
      end

      it "should deserialize an associative array" do
        input = object_fixture("amf3-associative-array.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == {0=>"bar1", 1=>"bar2", 2=>"bar3", "asdf"=>"fdsa", "foo"=>"bar", "42"=>"bar"}
      end

      it "should deserialize an array of mixed objects" do
        input = object_fixture("amf3-mixed-array.bin")
        output = RocketAMF.deserialize(input, 3)

        h1 = {'foo_one' => "bar_one"}
        h2 = {'foo_two' => ""}
        so1 = {'foo_three' => 42}
        output.should == [h1, h2, so1, {}, [h1, h2, so1], [], 42, "", [], "", {}, "bar_one", so1]
      end

      it "should deserialize an array collection as an array" do
        input = object_fixture("amf3-array-collection.bin")
        output = RocketAMF.deserialize(input, 3)

        output.class.should == Array
        output.should == ["foo", "bar"]
      end

      it "should deserialize a complex set of array collections" do
        RocketAMF::ClassMapper.define {|m| m.map :as => 'org.amf.ASClass', :ruby => 'RubyClass'}
        input = object_fixture('amf3-complex-array-collection.bin')

        output = RocketAMF.deserialize(input, 3)

        output[0].should == ["foo", "bar"]
        output[1][0].should be_a(RubyClass)
        output[1][1].should be_a(RubyClass)
        output[2].should === output[1]
      end

      it "should deserialize a byte array" do
        input = object_fixture("amf3-byte-array.bin")
        output = RocketAMF.deserialize(input, 3)

        output.should be_a(StringIO)
        expected = "\000\003これtest\100"
        expected.force_encoding("ASCII-8BIT") if expected.respond_to?(:force_encoding)
        output.string.should == expected
      end

      it "should deserialize an empty dictionary" do
        input = object_fixture("amf3-empty-dictionary.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == {}
      end

      it "should deserialize a dictionary" do
        input = object_fixture("amf3-dictionary.bin")
        output = RocketAMF.deserialize(input, 3)

        keys = output.keys
        keys.length.should == 2
        obj_key, str_key = keys[0].is_a?(RocketAMF::Values::TypedHash) ? [keys[0], keys[1]] : [keys[1], keys[0]]
        obj_key.type.should == 'org.amf.ASClass'
        output[obj_key].should == "asdf2"
        str_key.should == "bar"
        output[str_key].should == "asdf1"
      end

      it "should deserialize Vector.<int>" do
        input = object_fixture('amf3-vector-int.bin')
        output = RocketAMF.deserialize(input, 3)
        output.should == [4, -20, 12]
      end

      it "should deserialize Vector.<uint>" do
        input = object_fixture('amf3-vector-uint.bin')
        output = RocketAMF.deserialize(input, 3)
        output.should == [4, 20, 12]
      end

      it "should deserialize Vector.<Number>" do
        input = object_fixture('amf3-vector-double.bin')
        output = RocketAMF.deserialize(input, 3)
        output.should == [4.3, -20.6]
      end

      it "should deserialize Vector.<Object>" do
        input = object_fixture('amf3-vector-object.bin')
        output = RocketAMF.deserialize(input, 3)
        output[0]['foo'].should == 'foo'
        output[1].type.should == 'org.amf.ASClass'
        output[2]['foo'].should == 'baz'
      end
    end

    describe "and implementing the AMF Spec" do
      it "should keep references of duplicate strings" do
        input = object_fixture("amf3-string-ref.bin")
        output = RocketAMF.deserialize(input, 3)

        foo = "foo"
        bar = "str"
        output.should == [foo, bar, foo, bar, foo, {'str' => "foo"}]
      end

      it "should not reference the empty string" do
        input = object_fixture("amf3-empty-string-ref.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == ["",""]
      end

      it "should keep references of duplicate dates" do
        input = object_fixture("amf3-date-ref.bin")
        output = RocketAMF.deserialize(input, 3)

        output[0].should == Time.at(0)
        output[0].should equal(output[1])
        # Expected object:
        # [DateTime.parse "1/1/1970", DateTime.parse "1/1/1970"]
      end

      it "should keep reference of duplicate objects" do
        input = object_fixture("amf3-object-ref.bin")
        output = RocketAMF.deserialize(input, 3)

        obj1 = {'foo' => "bar"}
        obj2 = {'foo' => obj1['foo']}
        output.should == [[obj1, obj2], "bar", [obj1, obj2]]
      end

      it "should keep reference of duplicate object traits" do
        RocketAMF::ClassMapper.define {|m| m.map :as => 'org.amf.ASClass', :ruby => 'RubyClass'}

        input = object_fixture("amf3-trait-ref.bin")
        output = RocketAMF.deserialize(input, 3)

        output[0].foo.should == "foo"
        output[1].foo.should == "bar"
      end

      it "should keep references of duplicate arrays" do
        input = object_fixture("amf3-array-ref.bin")
        output = RocketAMF.deserialize(input, 3)

        a = [1,2,3]
        b = %w{ a b c }
        output.should == [a, b, a, b]
      end

      it "should not keep references of duplicate empty arrays unless the object_id matches" do
        input = object_fixture("amf3-empty-array-ref.bin")
        output = RocketAMF.deserialize(input, 3)

        a = []
        b = []
        output.should == [a,b,a,b]
      end

      it "should keep references of duplicate XML and XMLDocuments" do
        input = object_fixture("amf3-xml-ref.bin")
        output = RocketAMF.deserialize(input, 3)
        output.should == ['<parent><child prop="test"/></parent>', '<parent><child prop="test"/></parent>']
      end

      it "should keep references of duplicate byte arrays" do
        input = object_fixture("amf3-byte-array-ref.bin")
        output = RocketAMF.deserialize(input, 3)
        output[0].object_id.should == output[1].object_id
        output[0].string.should == "ASDF"
      end

      it "should deserialize a deep object graph with circular references" do
        input = object_fixture("amf3-graph-member.bin")
        output = RocketAMF.deserialize(input, 3)

        output['children'][0]['parent'].should === output
        output['parent'].should === nil
        output['children'].length.should == 2
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