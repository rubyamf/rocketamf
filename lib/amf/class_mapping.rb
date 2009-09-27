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

    # Creates a ruby object using the mapping configuration based on the source
    # AS class name. Then, it populates the ruby object using the based in properties
    def populate_ruby_obj as_class_name, props #:nodoc:
      # Create ruby object
      ruby_class_name = mappings.get_ruby_class_name as_class_name
      if ruby_class_name.nil?
        # Populate a simple hash, since no mapping
        ruby_obj = {}
      else
        ruby_class = ruby_class_name.split('::').inject(Kernel) {|scope, const_name| scope.const_get(const_name)}
        ruby_obj = ruby_class.new
      end

      # Populate
      props.each do |key, value|
        if ruby_obj.respond_to?("#{key}=")
          ruby_obj.send("#{key}=", value)
        elsif ruby_obj.respond_to?("[]=")
          ruby_obj[key.to_s] = value
        end
      end

      # Return object
      ruby_obj
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