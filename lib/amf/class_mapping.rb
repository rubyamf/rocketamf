require 'amf/values/typed_hash'
require 'amf/values/array_collection'
require 'amf/values/messages'

module AMF
  # == Class Mapping
  #
  # Handles class name mapping between actionscript and ruby and assists in
  # serializing and deserializing data between them. Simply map an AS class to a
  # ruby class and when the object is (de)serialized it will end up as the
  # appropriate class.
  #
  # Example:
  #
  #   AMF::ClassMapper.define do |m|
  #     m.map :as => 'AsClass', :ruby => 'RubyClass'
  #     m.map :as => 'vo.User', :ruby => 'User'
  #   end
  class ClassMapping
    # Container for all mapped classes
    class MappingSet
      def initialize #:nodoc:
        @as_mappings = {}
        @ruby_mappings = {}

        # Map defaults
        map :as => 'flex.messaging.messages.AbstractMessage', :ruby => 'AMF::Values::AbstractMessage'
        map :as => 'flex.messaging.messages.RemotingMessage', :ruby => 'AMF::Values::RemotingMessage'
        map :as => 'flex.messaging.messages.AsyncMessage', :ruby => 'AMF::Values::AsyncMessage'
        map :as => 'flex.messaging.messages.CommandMessage', :ruby => 'AMF::Values::CommandMessage'
        map :as => 'flex.messaging.messages.AcknowledgeMessage', :ruby => 'AMF::Values::AcknowledgeMessage'
        map :as => 'flex.messaging.messages.ErrorMessage', :ruby => 'AMF::Values::ErrorMessage'
        map :as => 'flex.messaging.io.ArrayCollection', :ruby => 'AMF::Values::ArrayCollection'
      end

      # Map a given AS class to a ruby class.
      #
      # Use fully qualified names for both.
      #
      # Example:
      #
      #   m.map :as 'com.example.Date', :ruby => 'Example::Date'
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

    # Array of custom object populators. Processed in array order, they must
    # respond to the "can_handle?" and "populate" methods.
    #
    # Example:
    #
    #   class CustomPopulator
    #     def can_handle? obj
    #       true
    #     end
    #   
    #     def populate obj, props, dynamic_props
    #       obj.merge! props
    #       obj.merge!(dynamic_props) if dynamic_props
    #     end
    #   end
    #   AMF::ClassMapper.object_populators << CustomPopulator.new
    attr_reader :object_populators

    # Array of custom object serializers. Processed in array order, they must
    # respond to the "can_handle?" and "serialize" methods.
    #
    # Example:
    #
    #   class CustomSerializer
    #     def can_handle? obj
    #       true
    #     end
    #   
    #     def serialize obj
    #       {}
    #     end
    #   end
    #   AMF::ClassMapper.object_serializers << CustomSerializer.new
    attr_reader :object_serializers

    def initialize #:nodoc:
      @object_populators = []
      @object_serializers = []
    end

    # Define class mappings in the block
    #
    # Example:
    #
    #   AMF::ClassMapper.define do |m|
    #     m.map :as => 'AsClass', :ruby => 'RubyClass'
    #   end
    def define
      yield mappings
    end

    # Returns the AS class name for the given ruby object. Will also take a string
    # containing the ruby class name
    def get_as_class_name obj #:nodoc:
      # Get class name
      if obj.is_a?(String)
        ruby_class_name = obj
      elsif obj.is_a?(Values::TypedHash)
        ruby_class_name = obj.type
      else
        ruby_class_name = obj.class.name
      end

      # Get mapped AS class name
      mappings.get_as_class_name ruby_class_name
    end

    # Instantiates a ruby object using the mapping configuration based on the
    # source AS class name. If there is no mapping defined, it returns a hash.
    def get_ruby_obj as_class_name #:nodoc:
      ruby_class_name = mappings.get_ruby_class_name as_class_name
      if ruby_class_name.nil?
        # Populate a simple hash, since no mapping
        return Values::TypedHash.new(as_class_name)
      else
        ruby_class = ruby_class_name.split('::').inject(Kernel) {|scope, const_name| scope.const_get(const_name)}
        return ruby_class.new
      end
    end

    # Populates the ruby object using the given properties
    def populate_ruby_obj obj, props, dynamic_props=nil #:nodoc:
      # Process custom populators
      @object_populators.each do |p|
        next unless p.can_handle?(obj)
        p.populate obj, props, dynamic_props
        return obj
      end

      # Fallback populator
      props.merge! dynamic_props if dynamic_props
      hash_like = obj.respond_to?("[]=")
      props.each do |key, value|
        if obj.respond_to?("#{key}=")
          obj.send("#{key}=", value)
        elsif hash_like
          obj[key.to_sym] = value
        end
      end
      obj
    end

    # Extracts all exportable properties from the given ruby object and returns
    # them in a hash
    def props_for_serialization ruby_obj #:nodoc:
      # Proccess custom serializers
      @object_serializers.each do |s|
        next unless s.can_handle?(ruby_obj)
        return s.serialize(ruby_obj)
      end

      # Handle hashes
      if ruby_obj.is_a?(Hash)
        # Stringify keys to make it easier later on and allow sorting
        h = {}
        ruby_obj.each {|k,v| h[k.to_s] = v}
        return h
      end

      # Fallback serializer
      props = {}
      ruby_obj.public_methods(false).each do |method_name|
        # Add them to the prop hash if they take no arguments
        method_def = ruby_obj.method(method_name)
        props[method_name] = ruby_obj.send(method_name) if method_def.arity == 0
      end
      props
    end

    private
    def mappings
      @mappings ||= MappingSet.new
    end
  end
end