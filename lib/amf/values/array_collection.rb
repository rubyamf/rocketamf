module AMF
  module Values #:nodoc:
    class ArrayCollection
      def externalized_data=(data)
        @data = data
      end
    end
  end
end