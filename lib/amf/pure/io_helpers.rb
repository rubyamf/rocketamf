module AMF
  module Pure
    module IOHelpers #:nodoc:
      def read_int8 source
        source.readbytes(1).unpack('c').first
      end

      def read_word8 source
        source.readbytes(1).unpack('C').first
      end

      def read_double source
        source.readbytes(8).unpack('G').first
      end

      def read_word16_network source
        source.readbytes(2).unpack('n').first
      end

      def read_int16_network source
        str = source.readbytes(2)
        str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
        str.unpack('s').first
      end

      def read_word32_network source
        source.readbytes(4).unpack('N').first
      end

      def byte_order
        if [0x12345678].pack("L") == "\x12\x34\x56\x78"
          :BigEndian
        else
          :LittleEndian
        end
      end

      def byte_order_little?
        (byte_order == :LittleEndian) ? true : false;
      end

      def pack_integer(integer)
        integer = integer & 0x1fffffff
        if(integer < 0x80)
          [integer].pack('c')
        elsif(integer < 0x4000)
          [integer >> 7 & 0x7f | 0x80].pack('c')+
          [integer & 0x7f].pack('c')
        elsif(integer < 0x200000)
          [integer >> 14 & 0x7f | 0x80].pack('c') +
          [integer >> 7 & 0x7f | 0x80].pack('c') +
          [integer & 0x7f].pack('c')
        else
          [integer >> 22 & 0x7f | 0x80].pack('c')+
          [integer >> 15 & 0x7f | 0x80].pack('c')+
          [integer >> 8 & 0x7f | 0x80].pack('c')+
          [integer & 0xff].pack('c')
        end
      end

      def pack_double(double)
        [double].pack('G')
      end
    end
  end
end