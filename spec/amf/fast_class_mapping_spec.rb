require "spec_helper.rb"
require 'rocketamf_ext'

describe RocketAMF::Ext::FastClassMapping do
  before :each do
    RocketAMF::Ext::FastClassMapping.reset
    RocketAMF::Ext::FastClassMapping.define do |m|
      m.map :as => 'ASClass', :ruby => 'ClassMappingTest'
    end
    @mapper = RocketAMF::Ext::FastClassMapping.new
  end

  describe "class name mapping" do
    it "should allow resetting of mappings back to defaults" do
      @mapper.get_as_class_name('ClassMappingTest').should_not be_nil
      RocketAMF::Ext::FastClassMapping.reset
      @mapper = RocketAMF::Ext::FastClassMapping.new
      @mapper.get_as_class_name('ClassMappingTest').should be_nil
      @mapper.get_as_class_name('RocketAMF::Values::AcknowledgeMessage').should_not be_nil
    end

    it "should return AS class name for ruby objects" do
      @mapper.get_as_class_name(ClassMappingTest.new).should == 'ASClass'
      @mapper.get_as_class_name('ClassMappingTest').should == 'ASClass'
      @mapper.get_as_class_name(RocketAMF::Values::TypedHash.new('ClassMappingTest')).should == 'ASClass'
      @mapper.get_as_class_name('BadClass').should be_nil
    end

    it "should instantiate a ruby class" do
      @mapper.get_ruby_obj('ASClass').should be_a(ClassMappingTest)
    end

    it "should properly instantiate namespaced classes" do
      RocketAMF::Ext::FastClassMapping.mappings.map :as => 'ASClass', :ruby => 'ANamespace::TestRubyClass'
      @mapper = RocketAMF::Ext::FastClassMapping.new
      @mapper.get_ruby_obj('ASClass').should be_a(ANamespace::TestRubyClass)
    end

    it "should return a hash with original type if not mapped" do
      obj = @mapper.get_ruby_obj('UnmappedClass')
      obj.should be_a(RocketAMF::Values::TypedHash)
      obj.type.should == 'UnmappedClass'
    end

    it "should map special classes from AS by default" do
      as_classes = [
        'flex.messaging.messages.AcknowledgeMessage',
        'flex.messaging.messages.CommandMessage',
        'flex.messaging.messages.RemotingMessage'
      ]

      as_classes.each do |as_class|
        @mapper.get_ruby_obj(as_class).should_not be_a(RocketAMF::Values::TypedHash)
      end
    end

    it "should map special classes from ruby by default" do
      ruby_classes = [
        'RocketAMF::Values::AcknowledgeMessage',
        'RocketAMF::Values::ErrorMessage'
      ]

      ruby_classes.each do |obj|
        @mapper.get_as_class_name(obj).should_not be_nil
      end
    end

    it "should allow config modification" do
      RocketAMF::Ext::FastClassMapping.mappings.map :as => 'SecondClass', :ruby => 'ClassMappingTest'
      @mapper = RocketAMF::Ext::FastClassMapping.new
      @mapper.get_as_class_name(ClassMappingTest.new).should == 'SecondClass'
    end
  end

  describe "ruby object populator" do
    it "should populate a ruby class" do
      obj = @mapper.populate_ruby_obj ClassMappingTest.new, {:prop_a => 'Data'}
      obj.prop_a.should == 'Data'
    end

    it "should populate a typed hash" do
      obj = @mapper.populate_ruby_obj RocketAMF::Values::TypedHash.new('UnmappedClass'), {:prop_a => 'Data'}
      obj[:prop_a].should == 'Data'
    end
  end

  describe "property extractor" do
    it "should return hash without modification" do
      hash = {:a => 'test1', 'b' => 'test2'}
      props = @mapper.props_for_serialization(hash)
      props.should === hash
    end

    it "should extract object properties" do
      obj = ClassMappingTest.new
      obj.prop_a = 'Test A'

      hash = @mapper.props_for_serialization obj
      hash.should == {'prop_a' => 'Test A', 'prop_b' => nil}
    end

    it "should extract inherited object properties" do
      obj = ClassMappingTest2.new
      obj.prop_a = 'Test A'
      obj.prop_c = 'Test C'

      hash = @mapper.props_for_serialization obj
      hash.should == {'prop_a' => 'Test A', 'prop_b' => nil, 'prop_c' => 'Test C'}
    end

    it "should cache property lookups by instance" do
      class ClassMappingTest3; attr_accessor :prop_a; end;

      # Cache properties
      obj = ClassMappingTest3.new
      hash = @mapper.props_for_serialization obj

      # Add a method to ClassMappingTest3
      class ClassMappingTest3; attr_accessor :prop_b; end;

      # Test property list does not have new property
      obj = ClassMappingTest3.new
      obj.prop_a = 'Test A'
      obj.prop_b = 'Test B'
      hash = @mapper.props_for_serialization obj
      hash.should == {'prop_a' => 'Test A'}

      # Test that new class mapper *does* have new property (cache per instance)
      @mapper = RocketAMF::Ext::FastClassMapping.new
      hash = @mapper.props_for_serialization obj
      hash.should == {'prop_a' => 'Test A', 'prop_b' => 'Test B'}
    end
  end
end