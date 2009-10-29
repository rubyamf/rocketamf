module RocketAMF
  module Values #:nodoc:
    class ArrayCollection < Array
      def externalized_data=(data)
        push(*data)
      end
    end
  end
end