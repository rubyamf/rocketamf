module AMF
  class ClassMapping
    class MappingSet
      def initialize
        @as_mappings = {}
        @ruby_mappings = {}
      end

      def map params
        [:as, :ruby].each {|k| params[k] = params[k].to_s} # Convert params to strings
        @as_mappings[params[:as]] = params[:ruby]
        @ruby_mappings[params[:ruby]] = params[:as]
      end

      def get_as_class_name class_name
        @ruby_mappings[class_name.to_s]
      end

      def get_ruby_class_name class_name
        @as_mappings[class_name.to_s]
      end
    end

    def define
      yield mappings
    end

    def get_as_class_name obj
      if obj.is_a?(String)
        ruby_class_name = obj
      else
        ruby_class_name = obj.class.name
      end
      mappings.get_as_class_name ruby_class_name
    end

    def populate_ruby_obj as_class_name, props
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

    def props_for_serialization ruby_obj
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