require 'rocketamf/pure/io_helpers'

module RocketAMF
  module Pure
    # Pure ruby serializer for AMF0 and AMF3
    class Serializer
      attr_reader :stream, :version

      # Pass in the class mapper instance to use when serializing. This enables
      # better caching behavior in the class mapper and allows one to change
      # mappings between serialization attempts.
      def initialize class_mapper
        @class_mapper = class_mapper
        @stream = ""
        @depth = 0
      end

      # Serialize the given object using AMF0 or AMF3. Can be called from inside
      # encode_amf, but make sure to pass in the proper version or it may not be
      # possible to decode. Use the serializer version attribute for this.
      def serialize version, obj
        raise ArgumentError, "unsupported version #{version}" unless [0,3].include?(version)
        @version = version

        # Initialize caches
        if @depth == 0
          if @version == 0
            @ref_cache = SerializerCache.new :object
          else
            @string_cache = SerializerCache.new :string
            @object_cache = SerializerCache.new :object
            @trait_cache = SerializerCache.new :string
          end
        end
        @depth += 1

        # Perform serialization
        if @version == 0
          amf0_serialize(obj)
        else
          amf3_serialize(obj)
        end

        # Cleanup
        @depth -= 1
        if @depth == 0
          @ref_cache = nil
          @string_cache = nil
          @object_cache = nil
          @trait_cache = nil
        end

        return @stream
      end

      # Helper for writing arrays inside encode_amf. It uses the current AMF
      # version to write the array.
      def write_array arr
        if @version == 0
          amf0_write_array arr
        else
          amf3_write_array arr
        end
      end

      # Helper for writing objects inside encode_amf. It uses the current AMF
      # version to write the object. If you pass in a property hash, it will use
      # it rather than having the class mapper determine properties. For AMF3,
      # you can also specify a traits hash, which can be used to reduce serialized
      # data size or serialize things as externalizable.
      def write_object obj, props=nil, traits=nil
        if @version == 0
          amf0_write_object obj, props
        else
          amf3_write_object obj, props, traits
        end
      end

      private
      include RocketAMF::Pure::WriteIOHelpers

      def amf0_serialize obj
        if @ref_cache[obj] != nil
          amf0_write_reference @ref_cache[obj]
        elsif obj.respond_to?(:encode_amf)
          obj.encode_amf(self)
        elsif obj.is_a?(NilClass)
          amf0_write_null
        elsif obj.is_a?(TrueClass) || obj.is_a?(FalseClass)
          amf0_write_boolean obj
        elsif obj.is_a?(Numeric)
          amf0_write_number obj
        elsif obj.is_a?(Symbol) || obj.is_a?(String)
          amf0_write_string obj.to_s
        elsif obj.is_a?(Time)
          amf0_write_time obj
        elsif obj.is_a?(Date)
          amf0_write_date obj
        elsif obj.is_a?(Array)
          amf0_write_array obj
        elsif obj.is_a?(Hash) ||obj.is_a?(Object)
          amf0_write_object obj
        end
      end

      def amf0_write_null
        @stream << AMF0_NULL_MARKER
      end

      def amf0_write_boolean bool
        @stream << AMF0_BOOLEAN_MARKER
        @stream << pack_int8(bool ? 1 : 0)
      end

      def amf0_write_number num
        @stream << AMF0_NUMBER_MARKER
        @stream << pack_double(num)
      end

      def amf0_write_string str
        str = str.encode("UTF-8").force_encoding("ASCII-8BIT") if str.respond_to?(:encode)
        len = str.bytesize
        if len > 2**16-1
          @stream << AMF0_LONG_STRING_MARKER
          @stream << pack_word32_network(len)
        else
          @stream << AMF0_STRING_MARKER
          @stream << pack_int16_network(len)
        end
        @stream << str
      end

      def amf0_write_time time
        @stream << AMF0_DATE_MARKER

        time = time.getutc # Dup and convert to UTC
        milli = (time.to_f * 1000).to_i
        @stream << pack_double(milli)

        @stream << pack_int16_network(0) # Time zone
      end

      def amf0_write_date date
        @stream << AMF0_DATE_MARKER
        @stream << pack_double(date.strftime("%Q").to_i)
        @stream << pack_int16_network(0) # Time zone
      end

      def amf0_write_reference index
        @stream << AMF0_REFERENCE_MARKER
        @stream << pack_int16_network(index)
      end

      def amf0_write_array array
        @ref_cache.add_obj array
        @stream << AMF0_STRICT_ARRAY_MARKER
        @stream << pack_word32_network(array.length)
        array.each do |elem|
          amf0_serialize elem
        end
      end

      def amf0_write_object obj, props=nil
        @ref_cache.add_obj obj

        props = @class_mapper.props_for_serialization obj if props.nil?

        # Is it a typed object?
        class_name = @class_mapper.get_as_class_name obj
        if class_name
          class_name = class_name.encode("UTF-8").force_encoding("ASCII-8BIT") if class_name.respond_to?(:encode)
          @stream << AMF0_TYPED_OBJECT_MARKER
          @stream << pack_int16_network(class_name.bytesize)
          @stream << class_name
        else
          @stream << AMF0_OBJECT_MARKER
        end

        # Write prop list
        props.sort.each do |key, value| # Sort keys before writing
          key = key.encode("UTF-8").force_encoding("ASCII-8BIT") if key.respond_to?(:encode)
          @stream << pack_int16_network(key.bytesize)
          @stream << key
          amf0_serialize value
        end

        # Write end
        @stream << pack_int16_network(0)
        @stream << AMF0_OBJECT_END_MARKER
      end

      def amf3_serialize obj
        if obj.respond_to?(:encode_amf)
          obj.encode_amf(self)
        elsif obj.is_a?(NilClass)
          amf3_write_null
        elsif obj.is_a?(TrueClass)
          amf3_write_true
        elsif obj.is_a?(FalseClass)
          amf3_write_false
        elsif obj.is_a?(Numeric)
          amf3_write_numeric obj
        elsif obj.is_a?(Symbol) || obj.is_a?(String)
          amf3_write_string obj.to_s
        elsif obj.is_a?(Time)
          amf3_write_time obj
        elsif obj.is_a?(Date)
          amf3_write_date obj
        elsif obj.is_a?(StringIO)
          amf3_write_byte_array obj
        elsif obj.is_a?(Array)
          amf3_write_array obj
        elsif obj.is_a?(Hash) || obj.is_a?(Object)
          amf3_write_object obj
        end
      end

      def amf3_write_reference index
        header = index << 1 # shift value left to leave a low bit of 0
        @stream << pack_integer(header)
      end

      def amf3_write_null
        @stream << AMF3_NULL_MARKER
      end

      def amf3_write_true
        @stream << AMF3_TRUE_MARKER
      end

      def amf3_write_false
        @stream << AMF3_FALSE_MARKER
      end

      def amf3_write_numeric num
        if !num.integer? || num < MIN_INTEGER || num > MAX_INTEGER # Check valid range for 29 bits
          @stream << AMF3_DOUBLE_MARKER
          @stream << pack_double(num)
        else
          @stream << AMF3_INTEGER_MARKER
          @stream << pack_integer(num)
        end
      end

      def amf3_write_string str
        @stream << AMF3_STRING_MARKER
        amf3_write_utf8_vr str
      end

      def amf3_write_time time
        @stream << AMF3_DATE_MARKER
        if @object_cache[time] != nil
          amf3_write_reference @object_cache[time]
        else
          # Cache time
          @object_cache.add_obj time

          # Build AMF string
          time = time.getutc # Dup and convert to UTC
          milli = (time.to_f * 1000).to_i
          @stream << AMF3_NULL_MARKER
          @stream << pack_double(milli)
        end
      end

      def amf3_write_date date
        @stream << AMF3_DATE_MARKER
        if @object_cache[date] != nil
          amf3_write_reference @object_cache[date]
        else
          # Cache date
          @object_cache.add_obj date

          # Build AMF string
          @stream << AMF3_NULL_MARKER
          @stream << pack_double(date.strftime("%Q").to_i)
        end
      end

      def amf3_write_byte_array array
        @stream << AMF3_BYTE_ARRAY_MARKER
        if @object_cache[array] != nil
          amf3_write_reference @object_cache[array]
        else
          @object_cache.add_obj array
          str = array.string
          @stream << pack_integer(str.bytesize << 1 | 1)
          @stream << str
        end
      end

      def amf3_write_array array
        # Is it an array collection?
        is_ac = false
        if array.respond_to?(:is_array_collection?)
          is_ac = array.is_array_collection?
        else
          is_ac = @class_mapper.use_array_collection
        end

        # Write type marker
        @stream << (is_ac ? AMF3_OBJECT_MARKER : AMF3_ARRAY_MARKER)

        # Write reference or cache array
        if @object_cache[array] != nil
          amf3_write_reference @object_cache[array]
          return
        else
          @object_cache.add_obj array
          @object_cache.add_obj nil if is_ac # The array collection source array
        end

        # Write out traits and array marker if it's an array collection
        if is_ac
          class_name = "flex.messaging.io.ArrayCollection"
          if @trait_cache[class_name] != nil
            @stream << pack_integer(@trait_cache[class_name] << 2 | 0x01)
          else
            @trait_cache.add_obj class_name
            @stream << "\a" # Externalizable, non-dynamic
            amf3_write_utf8_vr(class_name)
          end
          @stream << AMF3_ARRAY_MARKER
        end

        # Build AMF string for array
        header = array.length << 1 # make room for a low bit of 1
        header = header | 1 # set the low bit to 1
        @stream << pack_integer(header)
        @stream << AMF3_CLOSE_DYNAMIC_ARRAY
        array.each do |elem|
          amf3_serialize elem
        end
      end

      def amf3_write_object obj, props=nil, traits=nil
        @stream << AMF3_OBJECT_MARKER

        # Caching...
        if @object_cache[obj] != nil
          amf3_write_reference @object_cache[obj]
          return
        end
        @object_cache.add_obj obj

        # Calculate traits if not given
        is_default = false
        if traits.nil?
          traits = {
                    :class_name => @class_mapper.get_as_class_name(obj),
                    :members => [],
                    :externalizable => false,
                    :dynamic => true
                   }
          is_default = true unless traits[:class_name]
        end
        class_name = is_default ? "__default__" : traits[:class_name]

        # Write out traits
        if (class_name && @trait_cache[class_name] != nil)
          @stream << pack_integer(@trait_cache[class_name] << 2 | 0x01)
        else
          @trait_cache.add_obj class_name if class_name

          # Write out trait header
          header = 0x03 # Not object ref and not trait ref
          header |= 0x02 << 2 if traits[:dynamic]
          header |= 0x01 << 2 if traits[:externalizable]
          header |= traits[:members].length << 4
          @stream << pack_integer(header)

          # Write out class name
          if class_name == "__default__"
            amf3_write_utf8_vr("")
          else
            amf3_write_utf8_vr(class_name.to_s)
          end

          # Write out members
          traits[:members].each {|m| amf3_write_utf8_vr(m)}
        end

        # If externalizable, take externalized data shortcut
        if traits[:externalizable]
          obj.write_external(self)
          return
        end

        # Extract properties if not given
        props = @class_mapper.props_for_serialization(obj) if props.nil?

        # Write out sealed properties
        traits[:members].each do |m|
          amf3_serialize props[m]
          props.delete(m)
        end

        # Write out dynamic properties
        if traits[:dynamic]
          # Write out dynamic properties
          props.sort.each do |key, val| # Sort props until Ruby 1.9 becomes common
            amf3_write_utf8_vr key.to_s
            amf3_serialize val
          end

          # Write close
          @stream << AMF3_CLOSE_DYNAMIC_OBJECT
        end
      end

      def amf3_write_utf8_vr str, encode=true
        if str.respond_to?(:encode)
          if encode
            str = str.encode("UTF-8")
          else
            str = str.dup if str.frozen?
          end
          str.force_encoding("ASCII-8BIT")
        end

        if str == ''
          @stream << AMF3_EMPTY_STRING
        elsif @string_cache[str] != nil
          amf3_write_reference @string_cache[str]
        else
          # Cache string
          @string_cache.add_obj str

          # Build AMF string
          @stream << pack_integer(str.bytesize << 1 | 1)
          @stream << str
        end
      end
    end

    class SerializerCache #:nodoc:
      def self.new type
        if type == :string
          StringCache.new
        elsif type == :object
          ObjectCache.new
        end
      end

      class StringCache < Hash #:nodoc:
        def initialize
          @cache_index = 0
        end

        def add_obj str
          self[str] = @cache_index
          @cache_index += 1
        end
      end

      class ObjectCache < Hash #:nodoc:
        def initialize
          @cache_index = 0
          @obj_references = []
        end

        def [] obj
          super(obj.object_id)
        end

        def add_obj obj
          @obj_references << obj
          self[obj.object_id] = @cache_index
          @cache_index += 1
        end
      end
    end
  end
end
