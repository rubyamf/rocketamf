require File.dirname(__FILE__) + '/spec_helper.rb'

describe AMF::ClassMapping do
  before(:all) do
    # So we can get at the config object
    class AMF::ClassMapping
      attr_accessor :config
    end
  end

  before :each do
    @mapper = AMF::ClassMapping.new
  end

  it "should allow config modification" do
    @mapper.define do |c|
      c.map :as => 'FirstClass', :ruby => 'RubyClass'
    end
    @mapper.define do |c|
      c.map :as => 'SecondClass', :ruby => 'RubyClass'
    end

    @mapper.config.get_as_class_name('RubyClass').should == 'SecondClass'
  end
end