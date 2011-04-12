# Joc's monkeypatch for string bytesize (only available in 1.8.7+)
if !"amf".respond_to? :bytesize
  class String
    def bytesize
      self.size
    end
  end
end

# Add <tt>ArrayCollection</tt> override to arrays
class Array
  # Override <tt>RocketAMF::ClassMapper.use_array_collection</tt> setting for
  # this array. Adds <tt>is_array_collection?</tt> method, which is used by the
  # serializer over the global config if defined.
  def is_array_collection= a
    @is_array_collection = a

    def self.is_array_collection? #:nodoc:
      @is_array_collection
    end
  end
end