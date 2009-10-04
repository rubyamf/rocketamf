require 'amf/pure/io_helpers'

module AMF
  module Pure
    # AMF0 implementation of serializer
    class Serializer
      def initialize
        @ref_cache = SerializerCache.new
      end

      def version
        0
      end

      def serialize obj, stream = ""
        if @ref_cache[obj] != nil
          # Write reference header
        end
      end
    end

    # AMF3 implementation of serializer
    class AMF3Serializer
      attr_reader :string_cache

      def initialize
        @string_cache = SerializerCache.new
        @object_cache = SerializerCache.new
      end

      def version
        3
      end

      def serialize obj, stream = ""
        if obj.respond_to?(:to_amf)
          stream << obj.to_amf(self)
        elsif obj.is_a?(NilClass)
          write_null stream
        elsif obj.is_a?(TrueClass)
          write_true stream
        elsif obj.is_a?(FalseClass)
          write_false stream
        elsif obj.is_a?(Float)
          write_float obj, stream
        elsif obj.is_a?(Integer)
          write_integer obj, stream
        elsif obj.is_a?(Symbol) || obj.is_a?(String)
          write_string obj.to_s, stream
        elsif obj.is_a?(Time)
          write_date obj, stream
        elsif obj.is_a?(Array)
          write_array obj, stream
        elsif obj.is_a?(Hash) || obj.is_a?(Object)
          write_object obj, stream
        end
        stream
      end

      def write_reference index, stream
        header = index << 1 # shift value left to leave a low bit of 0
        stream << pack_integer(header)
      end

      def write_null stream
        stream << AMF3_NULL_MARKER
      end

      def write_true stream
        stream << AMF3_TRUE_MARKER
      end

      def write_false stream
        stream << AMF3_FALSE_MARKER
      end

      def write_integer int, stream
        if int < MIN_INTEGER || int > MAX_INTEGER # Check valid range for 29 bits
          write_float int.to_f, stream
        else
          stream << AMF3_INTEGER_MARKER
          stream << pack_integer(int)
        end
      end

      def write_float float, stream
        stream << AMF3_DOUBLE_MARKER
        stream << pack_double(float)
      end

      def write_string str, stream
        stream << AMF3_STRING_MARKER
        write_utf8_vr str, stream
      end

      def write_date date, stream
        stream << AMF3_DATE_MARKER
        if @object_cache[date] != nil
          write_reference @object_cache[date], stream
        else
          # Cache date
          @object_cache.add_obj date

          # Build AMF string
          date.utc unless date.utc?
          seconds = (date.to_f * 1000).to_i
          stream << pack_integer(AMF3_NULL_MARKER)
          stream << pack_double(seconds)
        end
      end

      def write_array array, stream
        stream << AMF3_ARRAY_MARKER
        if @object_cache[array] != nil
          write_reference @object_cache[array], stream
        else
          # Cache array
          @object_cache.add_obj array

          # Build AMF string
          header = array.length << 1 # make room for a low bit of 1
          header = header | 1 # set the low bit to 1
          stream << pack_integer(header)
          stream << CLOSE_DYNAMIC_ARRAY
          array.each do |elem|
            serialize elem, stream
          end
        end
      end

      def write_object obj, stream
        stream << AMF3_OBJECT_MARKER
        if @object_cache[obj] != nil
          write_reference @object_cache[obj], stream
        else
          # Cache object
          @object_cache.add_obj obj

          class_name = ClassMapper.get_as_class_name obj

          # Any object that has a class name isn't dynamic
          unless class_name
            stream << DYNAMIC_OBJECT
          end

          # Write class name/anonymous
          if class_name
            write_utf8_vr class_name, stream
          else
            stream << ANONYMOUS_OBJECT
          end

          # Write out properties
          props = ClassMapper.props_for_serialization obj
          props.sort.each do |key, val| # Sort props until Ruby 1.9 becomes common
            write_utf8_vr key.to_s, stream
            serialize val, stream
          end

          # Write close
          stream << CLOSE_DYNAMIC_OBJECT
        end
      end

      private
      include AMF::Pure::WriteIOHelpers

      def write_utf8_vr str, stream
        if str == ''
          stream << EMPTY_STRING
        elsif @string_cache[str] != nil
          write_reference @string_cache[str], stream
        else
          # Cache string
          @string_cache.add_obj str

          # Build AMF string
          header = str.length << 1 # make room for a low bit of 1
          header = header | 1 # set the low bit to 1
          stream << pack_integer(header)
          stream << str
        end
      end
    end

    class SerializerCache #:nodoc:
      def initialize
        @cache_index = 0
        @store = {}
      end

      def [] obj
        @store[object_key(obj)]
      end

      def []= obj, value
        @store[object_key(obj)] = value
      end

      def add_obj obj
        key = object_key obj
        if @store[key].nil?
          @store[key] = @cache_index
          @cache_index += 1
        end
      end

      private
      def object_key obj
        if obj.is_a?(String)
          obj
        else
          obj.object_id
        end
      end
    end
  end
end