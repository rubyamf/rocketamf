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

    private
    def mappings
      @mappings ||= MappingSet.new
    end
  end
end