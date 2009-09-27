require File.dirname(__FILE__) + '/spec_helper.rb'

describe AMF::ClassMapping do
  before(:all) do
    class RubyClass
      attr_accessor :prop_a
      attr_accessor :prop_b
      attr_accessor :prop_c
    end
  end

  before :each do
    @mapper = AMF::ClassMapping.new
    @mapper.define do |m|
      m.map :as => 'ASClass', :ruby => 'RubyClass'
    end
  end

  it "should return AS class name for ruby objects" do
    @mapper.get_as_class_name(RubyClass.new).should == 'ASClass'
    @mapper.get_as_class_name('RubyClass').should == 'ASClass'
  end

  it "should allow config modification" do
    @mapper.define do |m|
      m.map :as => 'SecondClass', :ruby => 'RubyClass'
    end
    @mapper.get_as_class_name(RubyClass.new).should == 'SecondClass'
  end

  describe "ruby object populator" do
    it "should populate ruby objects from AS data" do
      obj = @mapper.populate_ruby_obj 'ASClass', {:prop_a => 'Data'}
      obj.prop_a.should == 'Data'
    end

    it "should populate a hash if no mapping" do
      obj = @mapper.populate_ruby_obj 'BadClass', {:prop_a => 'Data'}
      obj.should be_a(Hash)
      obj['prop_a'].should == 'Data'
    end
  end

  it "should extract props for serialization" do
    obj = RubyClass.new
    obj.prop_a = 'Test A'
    obj.prop_b = 'Test B'

    hash = @mapper.props_for_serialization obj
    hash.should == {'prop_a' => 'Test A', 'prop_b' => 'Test B', 'prop_c' => nil}
  end
end