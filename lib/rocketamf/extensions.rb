# Joc's monkeypatch for string bytesize (only available in 1.8.7+)
if !"amf".respond_to? :bytesize
  class String
    def bytesize
      self.size
    end
  end
end

# Add ArrayCollection override to arrays
class Array
  def is_array_collection= a
    @is_array_collection = a

    def self.is_array_collection?
      @is_array_collection
    end
  end
end