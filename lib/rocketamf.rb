$:.unshift(File.dirname(__FILE__)) unless $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
$:.unshift "#{File.expand_path(File.dirname(__FILE__))}/rocketamf/"

require "date"
require "stringio"
require 'rocketamf/extensions'
require 'rocketamf/class_mapping'
require 'rocketamf/constants'
require 'rocketamf/remoting'

# RocketAMF is a full featured AMF0/3 serializer and deserializer with support
# for Flash -> Ruby and Ruby -> Flash class mapping, custom serializers,
# remoting gateway helpers that follow AMF0/3 messaging specs, and a suite of
# specs to ensure adherence to the specification documents put out by Adobe.
#
# == Serialization & Deserialization
#
# RocketAMF provides two main methods - <tt>RocketAMF.serialize(obj, amf_version=0)</tt>
# and <tt>RocketAMF.deserialize(source, amf_version=0)</tt>. To use, simple pass
# in the string to deserialize and the version if different from the default. To
# serialize an object, simply call <tt>RocketAMF.serialize</tt> with the object
# and the proper version. If you're working only with AS3, it is more effiecient
# to use the version 3 encoding, as it caches duplicate string to reduce
# serialized size. However for greater compatibility the default, AMF version 0,
# should work fine.
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
# In addition, you can use rack-amf (http://github.com/warhammerkid/rack-amf)
# which simplifies the code necessary to set up a functioning AMF gateway.
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
module RocketAMF
  begin
    require 'rocketamf/ext'
  rescue LoadError
    require 'rocketamf/pure'
  end

  # Deserialize the AMF string _source_ of the given AMF version into a Ruby
  # data structure and return it
  def self.deserialize source, amf_version = 0
    RocketAMF::Deserializer.new.deserialize(amf_version, source)
  end

  # Serialize the given Ruby data structure _obj_ into an AMF stream using the
  # given AMF version
  def self.serialize obj, amf_version = 0
    RocketAMF::Serializer.new.serialize(amf_version, obj)
  end

  # We use const_missing to define the active ClassMapper at runtime. This way,
  # heavy modification of class mapping functionality is still possible without
  # forcing extenders to redefine the constant.
  def self.const_missing const #:nodoc:
    if const == :ClassMapper
      RocketAMF.const_set(:ClassMapper, RocketAMF::ClassMapping.new)
    else
      super(const)
    end
  end

  # The base exception for AMF errors.
  class AMFError < StandardError; end
end