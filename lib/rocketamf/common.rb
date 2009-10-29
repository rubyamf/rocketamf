require 'rocketamf/version'
require 'rocketamf/class_mapping'
require 'rocketamf/constants'
require 'rocketamf/remoting'

module RocketAMF
  class << self
    # Deserialize the AMF string _source_ into a Ruby data structure and return it.
    def deserialize source, amf_version = 0
      if amf_version == 0
        RocketAMF::Deserializer.new.deserialize(source)
      elsif amf_version == 3
        RocketAMF::AMF3Deserializer.new.deserialize(source)
      else
        raise AMFError, "unsupported version #{amf_version}"
      end
    end

    # Serialize the given Ruby data structure _obj_ into an AMF stream
    def serialize obj, amf_version = 0
      if amf_version == 0
        RocketAMF::Serializer.new.serialize(obj)
      elsif amf_version == 3
        RocketAMF::AMF3Serializer.new.serialize(obj)
      else
        raise AMFError, "unsupported version #{amf_version}"
      end
    end
  end

  ClassMapper = RocketAMF::ClassMapping.new

  # The base exception for AMF errors.
  class AMFError < StandardError; end
end