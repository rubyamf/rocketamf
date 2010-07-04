module RocketAMF
  module Values #:nodoc:
    class ArrayCollection < Array
      def externalized_data
        [] + self # Duplicate as an array
      end

      def externalized_data=(data)
        push(*data)
      end
    end
  end
end