require 'rocketamf/pure/deserializer'
require 'rocketamf/pure/serializer'
require 'rocketamf/pure/remoting'

module RocketAMF
  # This module holds all the modules/classes that implement AMF's functionality
  # in pure ruby
  module Pure
    $DEBUG and warn "Using pure library for RocketAMF."
  end

  #:stopdoc:
  # Import deserializer
  Deserializer = RocketAMF::Pure::Deserializer
  AMF3Deserializer = RocketAMF::Pure::AMF3Deserializer

  # Import serializer
  Serializer = RocketAMF::Pure::Serializer
  AMF3Serializer = RocketAMF::Pure::AMF3Serializer

  # Modify envelope so it can serialize/deserialize
  class Envelope
    remove_method :populate_from_stream
    remove_method :serialize
    include RocketAMF::Pure::Envelope
  end
  #:startdoc:
end