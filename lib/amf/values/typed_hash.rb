module AMF
  class TypedHash < Hash
    attr_reader :original_type

    def initialize type
      @original_type = type
    end
  end
end