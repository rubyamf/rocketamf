$:.unshift(File.dirname(__FILE__)) unless $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
$:.unshift "#{File.expand_path(File.dirname(__FILE__))}/rocketamf/"

require 'rocketamf/version'
require 'rocketamf/class_mapping'
require 'rocketamf/constants'
require 'rocketamf/remoting'

module RocketAMF
  begin
    raise LoadError, 'C extensions not implemented'
  rescue LoadError
    require 'rocketamf/pure'
  end

  # Deserialize the AMF string _source_ of the given AMF version into a Ruby
  # data structure and return it
  def self.deserialize source, amf_version = 0
    if amf_version == 0
      RocketAMF::Deserializer.new.deserialize(source)
    elsif amf_version == 3
      RocketAMF::AMF3Deserializer.new.deserialize(source)
    else
      raise AMFError, "unsupported version #{amf_version}"
    end
  end

  # Serialize the given Ruby data structure _obj_ into an AMF stream using the
  # given AMF version
  def self.serialize obj, amf_version = 0
    if amf_version == 0
      RocketAMF::Serializer.new.serialize(obj)
    elsif amf_version == 3
      RocketAMF::AMF3Serializer.new.serialize(obj)
    else
      raise AMFError, "unsupported version #{amf_version}"
    end
  end

  # We use const_missing to define the active ClassMapper at runtime. This way,
  # heavy modification of class mapping functionality is still possible without
  # forcing extenders to redefine the constant.
  def self.const_missing const
    if const == :ClassMapper
      RocketAMF.const_set(:ClassMapper, RocketAMF::ClassMapping.new)
    else
      super(const)
    end
  end

  # The base exception for AMF errors.
  class AMFError < StandardError; end
end