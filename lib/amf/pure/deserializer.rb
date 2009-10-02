require 'bindata'
require 'amf/pure/io_helpers'

module AMF
  module Pure
    # Pure ruby deserializer
    #--
    # AMF0 deserializer, it switches over to AMF3 when it sees the switch flag
    class Deserializer
      def initialize
        @ref_cache = []
      end

      def deserialize(source, type=nil)
        source = BinData::IO.new(source) unless BinData::IO === source
        type = read_int8 source unless type
        case type
        when AMF0_NUMBER_MARKER
          read_number source
        when AMF0_BOOLEAN_MARKER
          read_boolean source
        when AMF0_STRING_MARKER
          read_string source
        when AMF0_OBJECT_MARKER
          read_object source
        when AMF0_NULL_MARKER
          nil
        when AMF0_UNDEFINED_MARKER
          nil
        when AMF0_REFERENCE_MARKER
          read_reference source
        when AMF0_HASH_MARKER
          read_hash source
        when AMF0_STRICT_ARRAY_MARKER
          read_array source
        when AMF0_DATE_MARKER
          read_date source
        when AMF0_LONG_STRING_MARKER
          read_string source, true
        when AMF0_UNSUPPORTED_MARKER
          nil
        when AMF0_XML_MARKER
          #read_xml source
        when AMF0_TYPED_OBJECT_MARKER
          read_typed_object source
        when AMF0_AMF3_MARKER
          AMF3Deserializer.new.deserialize(source)
        end
      end

      private
      include AMF::Pure::IOHelpers

      def read_number source
        res = read_double source
        res.is_a?(Float)&&res.nan? ? nil : res # check for NaN and convert them to nil
      end

      def read_boolean source
        read_int8(source) != 0
      end

      def read_string source, long=false
        len = long ? read_word32_network(source) : read_word16_network(source)
        source.readbytes(len)
      end

      def read_object source
        obj = {}
        while true
          key = read_string source
          type = read_int8 source
          break if type == AMF0_OBJECT_END_MARKER
          obj[key.to_sym] = deserialize(source, type)
        end
        @ref_cache << obj
        obj
      end

      def read_reference source
        index = read_word16_network(source)
        @ref_cache[index]
      end

      def read_hash source
        len = read_word32_network(source) # Read and ignore length

        # Read first pair
        key = read_string source
        type = read_int8 source
        return [] if type == AMF0_OBJECT_END_MARKER

        # We need to figure out whether this is a real hash, or whether some stupid serializer gave up
        if key.to_i.to_s == key
          # Array
          obj = []
          obj[key.to_i] = deserialize(source, type)
          while true
            key = read_string source
            type = read_int8 source
            break if type == AMF0_OBJECT_END_MARKER
            obj[key.to_i] = deserialize(source, type)
          end
        else
          # Hash
          obj = {key.to_sym => deserialize(source, type)}
          while true
            key = read_string source
            type = read_int8 source
            break if type == AMF0_OBJECT_END_MARKER
            obj[key.to_sym] = deserialize(source, type)
          end
        end
        @ref_cache << obj
        obj
      end

      def read_array source
        len = read_word32_network(source)
        array = []
        0.upto(len - 1) do
          array << deserialize(source)
        end
        @ref_cache << array
        array
      end

      def read_date source
        seconds = read_double(source).to_f/1000
        time = Time.at(seconds)
        tz = read_word16_network(source) # Unused
        time
      end

      def read_typed_object source
        class_name = read_string source
        props = read_object source
        @ref_cache.pop

        obj = ClassMapper.get_ruby_obj class_name
        ClassMapper.populate_ruby_obj obj, props, {}
        @ref_cache << obj
        obj
      end
    end

    # AMF3 implementation of deserializer, loaded automatically by the AMF0
    # deserializer when needed
    class AMF3Deserializer #:nodoc:
      def initialize
        @string_cache = []
        @object_cache = []
        @trait_cache = []
      end

      def deserialize(source, type=nil)
        source = BinData::IO.new(source) unless BinData::IO === source
        type = read_int8 source unless type
        case type
          when AMF3_UNDEFINED_MARKER
            nil
          when AMF3_NULL_MARKER
            nil
          when AMF3_FALSE_MARKER
            false
          when AMF3_TRUE_MARKER
            true
          when AMF3_INTEGER_MARKER
            read_integer source
          when AMF3_DOUBLE_MARKER
            read_number source
          when AMF3_STRING_MARKER
            read_string source
          when AMF3_XML_DOC_MARKER
            #read_xml_string
          when AMF3_DATE_MARKER
            read_date source
          when AMF3_ARRAY_MARKER
            read_array source
          when AMF3_OBJECT_MARKER
            read_object source
          when AMF3_XML_MARKER
            #read_amf3_xml
          when AMF3_BYTE_ARRAY_MARKER
            #read_amf3_byte_array
        end
      end

      private
      include AMF::Pure::IOHelpers

      def read_integer source
        n = 0
        b = read_word8(source) || 0
        result = 0

        while ((b & 0x80) != 0 && n < 3)
          result = result << 7
          result = result | (b & 0x7f)
          b = read_word8(source) || 0
          n = n + 1
        end

        if (n < 3)
          result = result << 7
          result = result | b
        else
          #Use all 8 bits from the 4th byte
          result = result << 8
          result = result | b

          #Check if the integer should be negative
          if (result > MAX_INTEGER)
            result -= (1 << 29)
          end
        end
        result
      end

      def read_number source
        res = read_double source
        res.is_a?(Float)&&res.nan? ? nil : res # check for NaN and convert them to nil
      end

      def read_string source
        type = read_integer source
        isReference = (type & 0x01) == 0

        if isReference
          reference = type >> 1
          return @string_cache[reference]
        else
          length = type >> 1
          #HACK needed for ['',''] array of empty strings
          #It may be better to take one more parameter that
          #would specify whether or not they expect us to return
          #a string
          str = "" #if stringRequest
          if length > 0
            str = source.readbytes(length)
            @string_cache << str
          end
          return str
        end
      end

      def read_array source
        type = read_integer source
        isReference = (type & 0x01) == 0

        if isReference
          reference = type >> 1
          return @object_cache[reference]
        else
          length = type >> 1
          propertyName = read_string source
          if propertyName != ""
            array = {}
            @object_cache << array
            begin
              while(propertyName.length)
                value = deserialize(source)
                array[propertyName] = value
                propertyName = read_string source
              end
            rescue Exception => e #end of object exception, because propertyName.length will be non existent
            end
            0.upto(length - 1) do |i|
              array["" + i.to_s] = deserialize(source)
            end
          else
            array = []
            @object_cache << array
            0.upto(length - 1) do
              array << deserialize(source)
            end
          end
          array
        end
      end

      def read_object source
        type = read_integer source
        isReference = (type & 0x01) == 0

        if isReference
          reference = type >> 1
          return @object_cache[reference]
        else
          class_type = type >> 1
          class_is_reference = (class_type & 0x01) == 0

          if class_is_reference
            reference = class_type >> 1
            class_definition = @trait_cache[reference]
          else
            class_name = read_string source
            externalizable = (class_type & 0x02) != 0
            dynamic = (class_type & 0x04) != 0
            attribute_count = class_type >> 3

            class_attributes = []
            attribute_count.times{class_attributes << read_string(source)} # Read class members

            class_definition = {"class_name" => class_name,
                                "members" => class_attributes,
                                "externalizable" => externalizable,
                                "dynamic" => dynamic}
            @trait_cache << class_definition
          end

          obj = ClassMapper.get_ruby_obj class_definition["class_name"]
          @object_cache << obj

          if class_definition['externalizable']
            obj.externalized_data = deserialize(source)
          else
            props = {}
            class_definition['members'].each do |key|
              value = deserialize(source)
              props[key.to_sym] = value
            end

            dynamic_props = nil
            if class_definition['dynamic']
              dynamic_props = {}
              while (key = read_string source) && key.length != 0  do # read next key
                value = deserialize(source)
                dynamic_props[key.to_sym] = value
              end
            end

            ClassMapper.populate_ruby_obj obj, props, dynamic_props
          end
          obj
        end
      end

      def read_date source
        type = read_integer source
        isReference = (type & 0x01) == 0
        if isReference
          reference = type >> 1
          return @object_cache[reference]
        else
          seconds = read_double(source).to_f/1000
          time = Time.at(seconds)
          @object_cache << time
          time
        end
      end
    end
  end
end