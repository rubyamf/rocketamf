require 'amf/values/typed_hash'

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
    #     def populate obj, props
    #       obj.merge! props
    #     end
    #   end
    #   AMF::ClassMapper.object_populators << CustomPopulator.new
    attr_reader :object_populators

    def initialize #:nodoc:
      @object_populators = []
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
      ruby_class_name = obj.is_a?(String) ? obj : obj.class.name
      mappings.get_as_class_name ruby_class_name
    end

    # Instantiates a ruby object using the mapping configuration based on the
    # source AS class name. If there is no mapping defined, it returns a hash.
    def get_ruby_obj as_class_name #:nodoc:
      ruby_class_name = mappings.get_ruby_class_name as_class_name
      if ruby_class_name.nil?
        # Populate a simple hash, since no mapping
        return TypedHash.new(as_class_name)
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
      props = {}
      ruby_obj.public_methods(false).each do |method_name|
        # Add them to the prop hash if they take no arguments
        method_def = ruby_obj.method(method_name)
        props[method_name.to_s] = ruby_obj.send(method_name) if method_def.arity == 0
      end
      props
    end

    private
    def mappings
      @mappings ||= MappingSet.new
    end
  end
end