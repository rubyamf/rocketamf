module RocketAMF
  module Values #:nodoc:
    class ArrayCollection < Array
      def read_external des
        push(*des.deserialize)
      end

      def write_external ser
        ser.serialize([] + self) # Duplicate as an array
      end
    end
  end
end