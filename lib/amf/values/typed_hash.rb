module AMF
  module Values #:nodoc:
    # Hash-like object that can store a type string. Used to preserve type information
    # for unmapped objects after deserialization.
    class TypedHash < Hash
      attr_reader :type

      def initialize type
        @type = type
      end
    end
  end
end