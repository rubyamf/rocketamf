require 'rocketamf/pure/io_helpers'

module RocketAMF
  module Pure
    # Request deserialization module - provides a method that can be included into
    # RocketAMF::Request for deserializing the given stream.
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
          name.force_encoding("UTF-8") if name.respond_to?(:force_encoding)
          must_understand = read_int8(stream) != 0
          length = read_word32_network stream
          data = RocketAMF.deserialize stream
          @headers << RocketAMF::Header.new(name, must_understand, data)
        end

        # Read in messages
        message_count = read_word16_network stream
        0.upto(message_count-1) do
          target_uri = stream.read(read_word16_network(stream))
          target_uri.force_encoding("UTF-8") if target_uri.respond_to?(:force_encoding)
          response_uri = stream.read(read_word16_network(stream))
          response_uri.force_encoding("UTF-8") if response_uri.respond_to?(:force_encoding)
          length = read_word32_network stream
          data = RocketAMF.deserialize stream
          if data.is_a?(Array) && data.length == 1 && data[0].is_a?(::RocketAMF::Values::AbstractMessage)
            data = data[0]
          end
          @messages << RocketAMF::Message.new(target_uri, response_uri, data)
        end

        self
      end

      private
      include RocketAMF::Pure::ReadIOHelpers
    end

    # Response serialization module - provides a method that can be included into
    # RocketAMF::Response for deserializing the given stream.
    module Response
      def serialize
        stream = ""

        # Write version
        stream << pack_int16_network(@amf_version)

        # Write headers
        stream << pack_int16_network(@headers.length) # Header count
        @headers.each do |h|
          name_str = h.name
          name_str.encode!("UTF-8") if name_str.respond_to?(:encode)
          stream << pack_int16_network(name_str.bytesize)
          stream << name_str
          stream << pack_int8(h.must_understand ? 1 : 0)
          stream << pack_word32_network(-1)
          stream << RocketAMF.serialize(h.data, 0)
        end

        # Write messages
        stream << pack_int16_network(@messages.length) # Message count
        @messages.each do |m|
          uri_str = m.target_uri
          uri_str.encode!("UTF-8") if uri_str.respond_to?(:encode)
          stream << pack_int16_network(uri_str.bytesize)
          stream << uri_str

          uri_str = m.response_uri
          uri_str.encode!("UTF-8") if uri_str.respond_to?(:encode)
          stream << pack_int16_network(uri_str.bytesize)
          stream << uri_str

          stream << pack_word32_network(-1)
          stream << AMF0_AMF3_MARKER if @amf_version == 3
          stream << RocketAMF.serialize(m.data, @amf_version)
        end

        stream.force_encoding("UTF-8") if stream.respond_to?(:force_encoding)
        stream
      end

      private
      include RocketAMF::Pure::WriteIOHelpers
    end
  end
end