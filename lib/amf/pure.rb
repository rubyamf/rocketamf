require 'amf/constants'
require 'amf/pure/deserializer'
require 'amf/pure/serializer'
require 'amf/pure/remoting'

module AMF
  # This module holds all the modules/classes that implement AMF's
  # functionality in pure ruby.
  module Pure
    $DEBUG and warn "Using pure library for AMF."
  end

  include AMF::Pure
end