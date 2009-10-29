require 'rocketamf/pure/deserializer'
require 'rocketamf/pure/serializer'
require 'rocketamf/pure/remoting'

module RocketAMF
  # This module holds all the modules/classes that implement AMF's
  # functionality in pure ruby.
  module Pure
    $DEBUG and warn "Using pure library for RocketAMF."
  end

  # Import Deserializer
  Deserializer = RocketAMF::Pure::Deserializer
  AMF3Deserializer = RocketAMF::Pure::AMF3Deserializer

  # Import serializer
  Serializer = RocketAMF::Pure::Serializer
  AMF3Serializer = RocketAMF::Pure::AMF3Serializer

  # Modify request and response so they can serialize/deserialize
  class Request
    include RocketAMF::Pure::Request
  end

  class Response
    include RocketAMF::Pure::Response
  end
end