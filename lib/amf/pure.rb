require 'amf/pure/deserializer'
require 'amf/pure/serializer'
require 'amf/pure/remoting'

module AMF
  # This module holds all the modules/classes that implement AMF's
  # functionality in pure ruby.
  module Pure
    $DEBUG and warn "Using pure library for AMF."
  end

  # Import Deserializer
  Deserializer = AMF::Pure::Deserializer
  AMF3Deserializer = AMF::Pure::AMF3Deserializer

  # Import serializer
  Serializer = AMF::Pure::Serializer
  AMF3Serializer = AMF::Pure::AMF3Serializer

  # Modify request and response so they can serialize/deserialize
  class Request
    include AMF::Pure::Request
  end

  class Response
    include AMF::Pure::Response
  end
end