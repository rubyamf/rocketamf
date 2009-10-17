module Rack::AMF
  # Rack specific wrapper around AMF::Request
  class Request
    attr_reader :raw_request

    def initialize env
      env['rack.input'].rewind
      @raw_request = ::AMF::Request.new.populate_from_stream(env['rack.input'].read)
    end

    # Returns the request AMF version
    def version
      raw_request.amf_version
    end

    # Returns all messages in the request
    def messages
      @raw_request.messages
    end
  end
end