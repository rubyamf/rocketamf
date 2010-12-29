require 'rocketamf/pure/io_helpers'

module RocketAMF
  module Pure
    # AMF0 implementation of serializer
    class Serializer
      attr_reader :ref_cache, :stream

      def initialize
        @ref_cache = SerializerCache.new :object
        @stream = ""
      end

      def version
        0
      end

      def serialize obj
        if @ref_cache[obj] != nil
          write_reference @ref_cache[obj]
        elsif obj.respond_to?(:encode_amf)
          obj.encode_amf(self)
        elsif obj.is_a?(NilClass)
          write_null
        elsif obj.is_a?(TrueClass) || obj.is_a?(FalseClass)
          write_boolean obj
        elsif obj.is_a?(Float) || obj.is_a?(Integer)
          write_number obj
        elsif obj.is_a?(Symbol) || obj.is_a?(String)
          write_string obj.to_s
        elsif obj.is_a?(Time)
          write_time obj
        elsif obj.is_a?(Date)
          write_date obj
        elsif obj.is_a?(Array)
          write_array obj
        elsif obj.is_a?(Hash)
          write_hash obj
        elsif obj.is_a?(Object)
          write_object obj
        end
        @stream
      end

      def write_null
        @stream << AMF0_NULL_MARKER
      end

      def write_boolean bool
        @stream << AMF0_BOOLEAN_MARKER
        @stream << pack_int8(bool ? 1 : 0)
      end

      def write_number num
        @stream << AMF0_NUMBER_MARKER
        @stream << pack_double(num)
      end

      def write_string str
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

      def write_time time
        @stream << AMF0_DATE_MARKER

        time = time.getutc # Dup and convert to UTC
        milli = (time.to_f * 1000).to_i
        @stream << pack_double(milli)

        @stream << pack_int16_network(0) # Time zone
      end

      def write_date date
        @stream << AMF0_DATE_MARKER
        @stream << pack_double(date.strftime("%Q").to_i)
        @stream << pack_int16_network(0) # Time zone
      end

      def write_reference index
        @stream << AMF0_REFERENCE_MARKER
        @stream << pack_int16_network(index)
      end

      def write_array array
        @ref_cache.add_obj array
        @stream << AMF0_STRICT_ARRAY_MARKER
        @stream << pack_word32_network(array.length)
        array.each do |elem|
          serialize elem
        end
      end

      def write_hash hash
        @ref_cache.add_obj hash
        @stream << AMF0_HASH_MARKER
        @stream << pack_word32_network(hash.length)
        write_prop_list RocketAMF::ClassMapper.props_for_serialization(hash)
      end

      def write_object obj, props=nil
        @ref_cache.add_obj obj

        props = RocketAMF::ClassMapper.props_for_serialization obj if props.nil?

        # Is it a typed object?
        class_name = RocketAMF::ClassMapper.get_as_class_name obj
        if class_name
          class_name = class_name.encode("UTF-8").force_encoding("ASCII-8BIT") if class_name.respond_to?(:encode)
          @stream << AMF0_TYPED_OBJECT_MARKER
          @stream << pack_int16_network(class_name.bytesize)
          @stream << class_name
        else
          @stream << AMF0_OBJECT_MARKER
        end

        write_prop_list props
      end

      private
      include RocketAMF::Pure::WriteIOHelpers
      def write_prop_list obj
        # Write prop list
        props = RocketAMF::ClassMapper.props_for_serialization obj
        props.sort.each do |key, value| # Sort keys before writing
          key = key.encode("UTF-8").force_encoding("ASCII-8BIT") if key.respond_to?(:encode)
          @stream << pack_int16_network(key.bytesize)
          @stream << key
          serialize value
        end

        # Write end
        @stream << pack_int16_network(0)
        @stream << AMF0_OBJECT_END_MARKER
      end
    end

    # AMF3 implementation of serializer
    class AMF3Serializer
      attr_reader :string_cache, :object_cache, :trait_cache, :stream

      def initialize
        @string_cache = SerializerCache.new :string
        @object_cache = SerializerCache.new :object
        @trait_cache = SerializerCache.new :trait
        @stream = ""
      end

      def version
        3
      end

      def serialize obj
        if obj.respond_to?(:encode_amf)
          obj.encode_amf(self)
        elsif obj.is_a?(NilClass)
          write_null
        elsif obj.is_a?(TrueClass)
          write_true
        elsif obj.is_a?(FalseClass)
          write_false
        elsif obj.is_a?(Float)
          write_float obj
        elsif obj.is_a?(Integer)
          write_integer obj
        elsif obj.is_a?(Symbol) || obj.is_a?(String)
          write_string obj.to_s
        elsif obj.is_a?(Time)
          write_time obj
        elsif obj.is_a?(Date)
          write_date obj
        elsif obj.is_a?(StringIO)
          write_byte_array obj
        elsif obj.is_a?(Array)
          write_array obj
        elsif obj.is_a?(Hash) || obj.is_a?(Object)
          write_object obj
        end
        @stream
      end

      def write_reference index
        header = index << 1 # shift value left to leave a low bit of 0
        @stream << pack_integer(header)
      end

      def write_null
        @stream << AMF3_NULL_MARKER
      end

      def write_true
        @stream << AMF3_TRUE_MARKER
      end

      def write_false
        @stream << AMF3_FALSE_MARKER
      end

      def write_integer int
        if int < MIN_INTEGER || int > MAX_INTEGER # Check valid range for 29 bits
          write_float int.to_f
        else
          @stream << AMF3_INTEGER_MARKER
          @stream << pack_integer(int)
        end
      end

      def write_float float
        @stream << AMF3_DOUBLE_MARKER
        @stream << pack_double(float)
      end

      def write_string str
        @stream << AMF3_STRING_MARKER
        write_utf8_vr str
      end

      def write_time time
        @stream << AMF3_DATE_MARKER
        if @object_cache[time] != nil
          write_reference @object_cache[time]
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

      def write_date date
        @stream << AMF3_DATE_MARKER
        if @object_cache[date] != nil
          write_reference @object_cache[date]
        else
          # Cache date
          @object_cache.add_obj date

          # Build AMF string
          @stream << AMF3_NULL_MARKER
          @stream << pack_double(date.strftime("%Q").to_i)
        end
      end

      def write_byte_array array
        @stream << AMF3_BYTE_ARRAY_MARKER
        if @object_cache[array] != nil
          write_reference @object_cache[array]
        else
          @object_cache.add_obj array
          write_utf8_vr array.string, false
        end
      end

      def write_array array
        # Is it an array collection?
        is_ac = false
        if array.respond_to?(:is_array_collection?)
          is_ac = array.is_array_collection?
        else
          is_ac = RocketAMF::ClassMapper.use_array_collection
        end

        # Write type marker
        @stream << (is_ac ? AMF3_OBJECT_MARKER : AMF3_ARRAY_MARKER)

        # Write reference or cache array
        if @object_cache[array] != nil
          write_reference @object_cache[array]
          return
        else
          @object_cache.add_obj array
        end

        # Write out traits and array marker if it's an array collection
        if is_ac
          class_name = "flex.messaging.io.ArrayCollection"
          traits = {:class_name => class_name}
          if @trait_cache[traits] != nil
            @stream << pack_integer(@trait_cache[traits] << 2 | 0x01)
          else
            @stream << "\a" # Externalizable, non-dynamic
            write_utf8_vr(class_name)
          end
          @stream << AMF3_ARRAY_MARKER
        end

        # Build AMF string for array
        header = array.length << 1 # make room for a low bit of 1
        header = header | 1 # set the low bit to 1
        @stream << pack_integer(header)
        @stream << AMF3_CLOSE_DYNAMIC_ARRAY
        array.each do |elem|
          serialize elem
        end
      end

      def write_object obj, props=nil, traits=nil
        @stream << AMF3_OBJECT_MARKER

        # Caching...
        if @object_cache[obj] != nil
          write_reference @object_cache[obj]
          return
        end
        @object_cache.add_obj obj

        # Calculate traits if not given
        if traits.nil?
          traits = {
                    :class_name => RocketAMF::ClassMapper.get_as_class_name(obj),
                    :members => [],
                    :externalizable => false,
                    :dynamic => true
                   }
        end

        # Write out traits
        if traits[:class_name] && @trait_cache[traits] != nil
          @stream << pack_integer(@trait_cache[traits] << 2 | 0x01)
        else
          @trait_cache.add_obj traits if traits[:class_name]

          # Write out trait header
          header = 0x03 # Not object ref and not trait ref
          header |= 0x02 << 2 if traits[:dynamic]
          header |= 0x01 << 2 if traits[:externalizable]
          header |= traits[:members].length << 4
          @stream << pack_integer(header)

          # Write out class name
          write_utf8_vr(traits[:class_name].to_s)

          # Write out members
          traits[:members].each {|m| write_utf8_vr(m)}
        end

        # If externalizable, take externalized data shortcut
        if traits[:externalizable]
          obj.write_external(self)
          return
        end

        # Extract properties if not given
        props = RocketAMF::ClassMapper.props_for_serialization(obj) if props.nil?

        # Write out sealed properties
        traits[:members].each do |m|
          serialize props[m]
          props.delete(m)
        end

        # Write out dynamic properties
        if traits[:dynamic]
          # Write out dynamic properties
          props.sort.each do |key, val| # Sort props until Ruby 1.9 becomes common
            write_utf8_vr key.to_s
            serialize val
          end

          # Write close
          @stream << AMF3_CLOSE_DYNAMIC_OBJECT
        end
      end

      private
      include RocketAMF::Pure::WriteIOHelpers

      def write_utf8_vr str, encode=true
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
          write_reference @string_cache[str]
        else
          # Cache string
          @string_cache.add_obj str

          # Build AMF string
          header = str.bytesize << 1 # make room for a low bit of 1
          header = header | 1 # set the low bit to 1
          @stream << pack_integer(header)
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
        elsif type == :trait
          TraitCache.new
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
        end

        def [] obj
          super(obj.object_id)
        end

        def add_obj obj
          self[obj.object_id] = @cache_index
          @cache_index += 1
        end
      end

      class TraitCache < Hash #:nodoc:
        def initialize
          @cache_index = 0
        end

        def [] obj
          super(obj[:class_name])
        end

        def add_obj obj
          self[obj[:class_name]] = @cache_index
          @cache_index += 1
        end
      end
    end
  end
end