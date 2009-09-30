require 'bindata'
require 'amf/pure/io_helpers'

module AMF
  module Pure
    # Pure ruby deserializer
    #--
    # AMF0 deserializer, it switches over to AMF3 when it sees the switch flag
    class Deserializer
      def initialize
        @amf3_deserializer = AMF3Deserializer.new
      end

      def deserialize_request(source)
        request = Request.new()
        request.read(source)
        return request
      end

      def deserialize(source, type=nil)
        @amf3_deserializer.deserialize(source, type)
      end

      private
      include AMF::Pure::IOHelpers
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
            str = readn(source, length)
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
          time = DateTime.strptime(seconds.to_s, "%s")
          @object_cache << time
          time
        end
      end

      include AMF::Pure::IOHelpers
    end
  end
end