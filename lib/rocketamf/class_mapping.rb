require 'rocketamf/values/typed_hash'
require 'rocketamf/values/messages'

module RocketAMF
  # Container for all mapped classes
  class MappingSet
    # Creates a mapping set object and populates the default mappings
    def initialize
      @as_mappings = {}
      @ruby_mappings = {}
      map_defaults
    end

    # Adds required mapping configs, calling map for the required base mappings.
    # Designed to allow extenders to take advantage of required default mappings.
    def map_defaults
      map :as => 'flex.messaging.messages.AbstractMessage', :ruby => 'RocketAMF::Values::AbstractMessage'
      map :as => 'flex.messaging.messages.RemotingMessage', :ruby => 'RocketAMF::Values::RemotingMessage'
      map :as => 'flex.messaging.messages.AsyncMessage', :ruby => 'RocketAMF::Values::AsyncMessage'
      map :as => 'DSA', :ruby => 'RocketAMF::Values::AsyncMessageExt'
      map :as => 'flex.messaging.messages.CommandMessage', :ruby => 'RocketAMF::Values::CommandMessage'
      map :as => 'DSC', :ruby => 'RocketAMF::Values::CommandMessageExt'
      map :as => 'flex.messaging.messages.AcknowledgeMessage', :ruby => 'RocketAMF::Values::AcknowledgeMessage'
      map :as => 'DSK', :ruby => 'RocketAMF::Values::AcknowledgeMessageExt'
      map :as => 'flex.messaging.messages.ErrorMessage', :ruby => 'RocketAMF::Values::ErrorMessage'
      self
    end

    # Map a given AS class to a ruby class.
    #
    # Use fully qualified names for both.
    #
    # Example:
    #
    #   m.map :as => 'com.example.Date', :ruby => 'Example::Date'
    def map params
      [:as, :ruby].each {|k| params[k] = params[k].to_s} # Convert params to strings
      @as_mappings[params[:as]] = params[:ruby]
      @ruby_mappings[params[:ruby]] = params[:as]
    end

    # Returns the AS class name for the given ruby class name, returing nil if
    # not found
    def get_as_class_name class_name #:nodoc:
      @ruby_mappings[class_name.to_s]
    end

    # Returns the ruby class name for the given AS class name, returing nil if
    # not found
    def get_ruby_class_name class_name #:nodoc:
      @as_mappings[class_name.to_s]
    end
  end

  # Handles class name mapping between actionscript and ruby and assists in
  # serializing and deserializing data between them. Simply map an AS class to a
  # ruby class and when the object is (de)serialized it will end up as the
  # appropriate class.
  #
  # Example:
  #
  #   RocketAMF::ClassMapper.define do |m|
  #     m.map :as => 'AsClass', :ruby => 'RubyClass'
  #     m.map :as => 'vo.User', :ruby => 'Model::User'
  #   end
  #
  # == Object Population/Serialization
  #
  # In addition to handling class name mapping, it also provides helper methods
  # for populating ruby objects from AMF and extracting properties from ruby objects
  # for serialization. Support for hash-like objects and objects using
  # <tt>attr_accessor</tt> for properties is currently built in, but custom classes
  # may require subclassing the class mapper to add support.
  #
  # == Complete Replacement
  #
  # In some cases, it may be beneficial to replace the default provider of class
  # mapping completely. In this case, simply assign your class mapper class to
  # <tt>RocketAMF::ClassMapper</tt> after loading RocketAMF. Through the magic of
  # <tt>const_missing</tt>, <tt>ClassMapper</tt> is only defined after the first
  # access by default, so you get no annoying warning messages. Custom class mappers
  # must implement the following methods on instances: <tt>use_array_collection</tt>,
  # <tt>get_as_class_name</tt>, <tt>get_ruby_obj</tt>, <tt>populate_ruby_obj</tt>,
  # and <tt>props_for_serialization</tt>. In addition, it should have a class level
  # <tt>mappings</tt> method that returns the mapping set it's using, although its
  # not required. If you'd like to see an example of what complete replacement
  # offers, check out RubyAMF (http://github.com/rubyamf/rubyamf).
  #
  # Example:
  #
  #   require 'rubygems'
  #   require 'rocketamf'
  #   
  #   RocketAMF::ClassMapper = MyCustomClassMapper
  #   # No warning about already initialized constant ClassMapper
  #   RocketAMF::ClassMapper # MyCustomClassMapper
  #
  # == C ClassMapper
  #
  # The C class mapper, <tt>RocketAMF::Ext::FastClassMapping</tt>, has the same
  # public API that <tt>RubyAMF::ClassMapping</tt> does, but has some additional
  # performance optimizations that may interfere with the proper serialization of
  # objects. To reduce the cost of processing public methods for every object,
  # its implementation of <tt>props_for_serialization</tt> caches valid properties
  # by class, using the class as the hash key for property lookup. This means that
  # adding and removing properties from instances while serializing using a given
  # class mapper instance will result in the changes not being detected.  As such,
  # it's not enabled by default. So long as you aren't planning on modifying
  # classes during serialization using <tt>encode_amf</tt>, the faster C class
  # mapper should be perfectly safe to use.
  #
  # Activating the C Class Mapper:
  #
  #   require 'rubygems'
  #   require 'rocketamf'
  #   RocketAMF::ClassMapper = RocketAMF::Ext::FastClassMapping
  class ClassMapping
    class << self
      # Global configuration variable for sending Arrays as ArrayCollections.
      # Defaults to false.
      attr_accessor :use_array_collection

      # Returns the mapping set with all the class mappings that is currently
      # being used.
      def mappings
        @mappings ||= MappingSet.new
      end

      # Define class mappings in the block. Block is passed a <tt>MappingSet</tt> object
      # as the first parameter.
      #
      # Example:
      #
      #   RocketAMF::ClassMapper.define do |m|
      #     m.map :as => 'AsClass', :ruby => 'RubyClass'
      #   end
      def define &block #:yields: mapping_set
        yield mappings
      end

      # Reset all class mappings except the defaults and return
      # <tt>use_array_collection</tt> to false
      def reset
        @use_array_collection = false
        @mappings = nil
      end
    end

    attr_reader :use_array_collection

    # Copies configuration from class level configs to populate object
    def initialize
      @mappings = self.class.mappings
      @use_array_collection = self.class.use_array_collection === true
    end

    # Returns the ActionScript class name for the given ruby object. Will also
    # take a string containing the ruby class name.
    def get_as_class_name obj
      # Get class name
      if obj.is_a?(String)
        ruby_class_name = obj
      elsif obj.is_a?(Values::TypedHash)
        ruby_class_name = obj.type
      elsif obj.is_a?(Hash)
        return nil
      else
        ruby_class_name = obj.class.name
      end

      # Get mapped AS class name
      @mappings.get_as_class_name ruby_class_name
    end

    # Instantiates a ruby object using the mapping configuration based on the
    # source ActionScript class name. If there is no mapping defined, it returns
    # a <tt>RocketAMF::Values::TypedHash</tt> with the serialized class name.
    def get_ruby_obj as_class_name
      ruby_class_name = @mappings.get_ruby_class_name as_class_name
      if ruby_class_name.nil?
        # Populate a simple hash, since no mapping
        return Values::TypedHash.new(as_class_name)
      else
        ruby_class = ruby_class_name.split('::').inject(Kernel) {|scope, const_name| scope.const_get(const_name)}
        return ruby_class.new
      end
    end

    # Populates the ruby object using the given properties. props and
    # dynamic_props will be hashes with symbols for keys.
    def populate_ruby_obj obj, props, dynamic_props=nil
      props.merge! dynamic_props if dynamic_props

      # Don't even bother checking if it responds to setter methods if it's a TypedHash
      if obj.is_a?(Values::TypedHash)
        obj.merge! props
        return obj
      end

      # Some type of object
      hash_like = obj.respond_to?("[]=")
      props.each do |key, value|
        if obj.respond_to?("#{key}=")
          obj.send("#{key}=", value)
        elsif hash_like
          obj[key] = value
        end
      end
      obj
    end

    # Extracts all exportable properties from the given ruby object and returns
    # them in a hash. If overriding, make sure to return a hash wth string keys
    # unless you are only going to be using the native C extensions, as the pure
    # ruby serializer performs a sort on the keys to acheive consistent, testable
    # results.
    def props_for_serialization ruby_obj
      # Handle hashes
      if ruby_obj.is_a?(Hash)
        # Stringify keys to make it easier later on and allow sorting
        h = {}
        ruby_obj.each {|k,v| h[k.to_s] = v}
        return h
      end

      # Generic object serializer
      props = {}
      @ignored_props ||= Object.new.public_methods
      (ruby_obj.public_methods - @ignored_props).each do |method_name|
        # Add them to the prop hash if they take no arguments
        method_def = ruby_obj.method(method_name)
        props[method_name.to_s] = ruby_obj.send(method_name) if method_def.arity == 0
      end
      props
    end
  end
end