require File.dirname(__FILE__) + '/../spec_helper.rb'

describe AMF::ClassMapping::MappingSet do
  before :each do
    @config = AMF::ClassMapping::MappingSet.new
  end

  it "should retrieve AS mapping for ruby class" do
    @config.map :as => 'ASTest', :ruby => 'RubyTest'
    @config.get_as_class_name('RubyTest').should == 'ASTest'
    @config.get_as_class_name('BadClass').should be_nil
  end

  it "should retrive ruby class name mapping for AS class" do
    @config.map :as => 'ASTest', :ruby => 'RubyTest'
    @config.get_ruby_class_name('ASTest').should == 'RubyTest'
    @config.get_ruby_class_name('BadClass').should be_nil
  end

  it "should map special classes by default" do
    SPECIAL_CLASSES = [
      'flex.messaging.messages.AcknowledgeMessage',
      'flex.messaging.messages.ErrorMessage',
      'flex.messaging.messages.CommandMessage',
      'flex.messaging.messages.ErrorMessage',
      'flex.messaging.messages.RemotingMessage',
      'flex.messaging.io.ArrayCollection'
    ]

    SPECIAL_CLASSES.each do |as_class|
      @config.get_ruby_class_name(as_class).should_not be_nil
    end
  end
end