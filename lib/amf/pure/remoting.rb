require 'amf/pure/io_helpers'

module AMF
  module Pure
    class Request
      attr_reader :amf_version, :headers, :messages

      def initialize
        @amf_version = 0
        @headers = []
        @messages = []
      end

      def populate_from_stream stream
        stream = StringIO.new(stream) unless StringIO === stream

        # Read AMF version
        @amf_version = read_word16_network stream

        # Read in headers
        header_count = read_word16_network stream
        0.upto(header_count-1) do
          name = stream.read(read_word16_network(stream))
          must_understand = read_int8(stream) != 0
          length = read_word32_network stream
          data = AMF.deserialize stream
          @headers << Header.new(name, must_understand, data)
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
          @messages << Message.new(target_uri, response_uri, data)
        end

        self
      end

      private
      include AMF::Pure::ReadIOHelpers
    end

    class Response
      attr_accessor :amf_version, :headers, :messages

      def initialize
        @amf_version = 3
        @headers = []
        @messages = []
      end

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

    class Header
      attr_accessor :name, :must_understand, :data

      def initialize name, must_understand, data
        @name = name
        @must_understand = must_understand
        @data = data
      end
    end

    class Message
      attr_accessor :target_uri, :response_uri, :data

      def initialize target_uri, response_uri, data
        @target_uri = target_uri
        @response_uri = response_uri
        @data = data
      end
    end
  end
end