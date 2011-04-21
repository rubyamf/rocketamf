$:.unshift(File.dirname(__FILE__)) unless $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
$:.unshift "#{File.expand_path(File.dirname(__FILE__))}/rocketamf/"

require "date"
require "stringio"
require 'rocketamf/extensions'
require 'rocketamf/class_mapping'
require 'rocketamf/constants'
require 'rocketamf/remoting'

# RocketAMF is a full featured AMF0/3 serializer and deserializer with support for
# bi-directional Flash to Ruby class mapping, custom serialization and mapping,
# remoting gateway helpers that follow AMF0/3 messaging specs, and a suite of specs
# to ensure adherence to the specification documents put out by Adobe. If the C
# components compile, then RocketAMF automatically takes advantage of them to
# provide a substantial performance benefit. In addition, RocketAMF is fully
# compatible with Ruby 1.9.
#
# == Performance
#
# RocketAMF provides native C extensions for serialization, deserialization,
# remoting, and class mapping. If your environment supports them, RocketAMF will
# automatically take advantage of the C serializer, deserializer, and remoting
# support. The C class mapper has some substantial performance optimizations that
# make it incompatible with the pure Ruby class mapper, and so it must be manually
# enabled. For more information see <tt>RocketAMF::ClassMapping</tt>. Below are
# some benchmarks I took using using a simple little benchmarking utility I whipped
# up, which can be found in the root of the repository.
#
#   # 100000 objects
#   # Ruby 1.8
#   Testing native AMF0:
#     minimum serialize time: 1.229868s
#     minimum deserialize time: 0.86465s
#   Testing native AMF3:
#     minimum serialize time: 1.444652s
#     minimum deserialize time: 0.879407s
#   Testing pure AMF0:
#     minimum serialize time: 25.427931s
#     minimum deserialize time: 11.706084s
#   Testing pure AMF3:
#     minimum serialize time: 31.637864s
#     minimum deserialize time: 14.773969s
#
# == Serialization & Deserialization
#
# RocketAMF provides two main methods - <tt>serialize</tt> and <tt>deserialize</tt>.
# Deserialization takes a String or StringIO object and the AMF version if different
# from the default. Serialization takes any Ruby object and the version if different
# from the default. Both default to AMF0, as it's more widely supported and slightly
# faster, but AMF3 does a better job of not sending duplicate data. Which you choose
# depends on what you need to communicate with and how much serialized size matters.
#
# == Mapping Classes Between Flash and Ruby
#
# RocketAMF provides a simple class mapping tool to facilitate serialization and
# deserialization of typed objects. Refer to the documentation of
# <tt>RocketAMF::ClassMapping</tt> for more details. If the provided class
# mapping tool is not sufficient for your needs, you also have the option to
# replace it with a class mapper of your own devising that matches the documented
# API.
#
# == Remoting
#
# You can use RocketAMF bare to write an AMF gateway using the following code.
# In addition, you can use rack-amf (http://github.com/rubyamf/rack-amf) or
# RubyAMF (http://github.com/rubyamf/rubyamf), both of which provide rack-compliant
# AMF gateways.
#
#   # helloworld.ru
#   require 'rocketamf'
#
#   class HelloWorldApp
#     APPLICATION_AMF = 'application/x-amf'.freeze
#
#     def call env
#       if is_amf?(env)
#         # Wrap request and response
#         env['rack.input'].rewind
#         request = RocketAMF::Envelope.new.populate_from_stream(env['rack.input'].read)
#         response = RocketAMF::Envelope.new
#
#         # Handle request
#         response.each_method_call request do |method, args|
#           raise "Service #{method} does not exists" unless method == 'App.helloWorld'
#           'Hello world'
#         end
#
#         # Pass back response
#         response_str = response.serialize
#         return [200, {'Content-Type' => APPLICATION_AMF, 'Content-Length' => response_str.length.to_s}, [response_str]]
#       else
#         return [200, {'Content-Type' => 'text/plain', 'Content-Length' => '16' }, ["Rack AMF gateway"]]
#       end
#     end
#
#     private
#     def is_amf? env
#       return false unless env['CONTENT_TYPE'] == APPLICATION_AMF
#       return false unless env['PATH_INFO'] == '/amf'
#       return true
#     end
#   end
#
#   run HelloWorldApp.new
#
# == Advanced Serialization (encode_amf and IExternalizable)
#
# RocketAMF provides some additional functionality to support advanced
# serialization techniques. If you define an <tt>encode_amf</tt> method on your
# object, it will get called during serialization. It is passed a single argument,
# the serializer, and it can use the serializer stream, the <tt>serialize</tt>
# method, the <tt>write_array</tt> method, the <tt>write_object</tt> method, and
# the serializer version. Below is a simple example that uses <tt>write_object</tt>
# to customize the property hash that is used for serialization.
#
# Example:
#
#   class TestObject
#     def encode_amf ser
#       ser.write_object self, @attributes
#     end
#   end
#
# If you plan on using the <tt>serialize</tt> method, make sure to pass in the
# current serializer version, or you could create a message that cannot be deserialized.
#
# Example:
#
#   class VariableObject
#     def encode_amf ser
#       if ser.version == 0
#         ser.serialize 0, true
#       else
#         ser.serialize 3, false
#       end
#     end
#   end
#
# If you wish to send and receive IExternalizable objects, you will need to
# implement <tt>encode_amf</tt>, <tt>read_external</tt>, and <tt>write_external</tt>.
# Below is an example of a ResultSet class that extends Array and serializes as
# an array collection. RocketAMF can automatically serialize arrays as
# ArrayCollection objects, so this is just an example of how you might implement
# an object that conforms to IExternalizable.
#
# Example:
#
#   class ResultSet < Array
#     def encode_amf ser
#       if ser.version == 0
#         # Serialize as simple array in AMF0
#         ser.write_array self
#       else
#         # Serialize as an ArrayCollection object
#         # It conforms to IExternalizable, does not have any dynamic properties,
#         # and has no "sealed" members. See the AMF3 specs for more details about
#         # object traits.
#         ser.write_object self, nil, {
#           :class_name => "flex.messaging.io.ArrayCollection",
#           :externalizable => true,
#           :dynamic => false,
#           :members => []
#         }
#       end
#     end
#   
#     # Force it to be converted to an array so we don't get into an endless loop,
#     # serialize, and append to data stream
#     def write_external stream
#       serialized = RocketAMF.serialize([]+self, 3)
#       stream << serialized
#     end
#   
#     # Read array out and replace data with deserialized array. Source is always
#     # a StringIO object.
#     def read_external source
#       replace RocketAMF.deserialize(source, 3)
#     end
#   end
module RocketAMF
  begin
    require 'rocketamf/ext'
  rescue LoadError
    require 'rocketamf/pure'
  end

  # Deserialize the AMF string _source_ of the given AMF version into a Ruby
  # data structure and return it. Creates an instance of <tt>RocketAMF::Deserializer</tt>
  # with a new instance of <tt>RocketAMF::ClassMapper</tt> and calls deserialize
  # on it with the given source and amf version, returning the result.
  def self.deserialize source, amf_version = 0
    des = RocketAMF::Deserializer.new(RocketAMF::ClassMapper.new)
    des.deserialize(amf_version, source)
  end

  # Serialize the given Ruby data structure _obj_ into an AMF stream using the
  # given AMF version. Creates an instance of <tt>RocketAMF::Serializer</tt>
  # with a new instance of <tt>RocketAMF::ClassMapper</tt> and calls serialize
  # on it with the given object and amf version, returning the result.
  def self.serialize obj, amf_version = 0
    ser = RocketAMF::Serializer.new(RocketAMF::ClassMapper.new)
    ser.serialize(amf_version, obj)
  end

  # We use const_missing to define the active ClassMapper at runtime. This way,
  # heavy modification of class mapping functionality is still possible without
  # forcing extenders to redefine the constant.
  def self.const_missing const #:nodoc:
    if const == :ClassMapper
      RocketAMF.const_set(:ClassMapper, RocketAMF::ClassMapping)
    else
      super(const)
    end
  end

  # The base exception for AMF errors.
  class AMFError < StandardError; end
end