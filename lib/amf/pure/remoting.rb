require 'amf/pure/io_helpers'

module AMF
  module Pure
    # Request deserialization module - provides a method that can be included into
    # AMF::Request for deserializing the given stream.
    module Request
      def populate_from_stream stream
        stream = StringIO.new(stream) unless StringIO === stream

        # Initialize
        @amf_version = 0
        @headers = []
        @messages = []

        # Read AMF version
        @amf_version = read_word16_network stream

        # Read in headers
        header_count = read_word16_network stream
        0.upto(header_count-1) do
          name = stream.read(read_word16_network(stream))
          must_understand = read_int8(stream) != 0
          length = read_word32_network stream
          data = AMF.deserialize stream
          @headers << AMF::Header.new(name, must_understand, data)
        end

        # Read in messages
        message_count = read_word16_network stream
        0.upto(message_count-1) do
          target_uri = stream.read(read_word16_network(stream))
          response_uri = stream.read(read_word16_network(stream))
          length = read_word32_network stream
          data = AMF.deserialize stream
          if data.is_a?(Array) && data.length == 1 && data[0].is_a?(::AMF::Values::AbstractMessage)
            data = data[0]
          end
          @messages << AMF::Message.new(target_uri, response_uri, data)
        end

        self
      end

      private
      include AMF::Pure::ReadIOHelpers
    end

    # Response serialization module - provides a method that can be included into
    # AMF::Response for deserializing the given stream.
    module Response
      def serialize
        stream = ""

        # Write version
        stream << pack_int16_network(@amf_version)

        # Write headers
        stream << pack_int16_network(@headers.length) # Header count
        @headers.each do |h|
          stream << pack_int16_network(h.name.length)
          stream << h.name
          stream << pack_int8(h.must_understand ? 1 : 0)
          stream << pack_word32_network(-1)
          stream << AMF.serialize(h.data, 0)
        end

        # Write messages
        stream << pack_int16_network(@messages.length) # Message count
        @messages.each do |m|
          stream << pack_int16_network(m.target_uri.length)
          stream << m.target_uri

          stream << pack_int16_network(m.response_uri.length)
          stream << m.response_uri

          stream << pack_word32_network(-1)
          stream << AMF0_AMF3_MARKER if @amf_version == 3
          stream << AMF.serialize(m.data, @amf_version)
        end

        stream
      end

      private
      include AMF::Pure::WriteIOHelpers
    end
  end
end