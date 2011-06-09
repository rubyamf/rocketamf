module RocketAMF
  module Values #:nodoc:
    # Base class for all special AS3 response messages. Maps to
    # <tt>flex.messaging.messages.AbstractMessage</tt>.
    class AbstractMessage
      EXTERNALIZABLE_FIELDS = [
        %w[ body clientId destination headers messageId timestamp timeToLive ],
        %w[ clientIdBytes messageIdBytes ]
      ]
      attr_accessor :clientId
      attr_accessor :destination
      attr_accessor :messageId
      attr_accessor :timestamp
      attr_accessor :timeToLive
      attr_accessor :headers
      attr_accessor :body

      def clientIdBytes= bytes
        @clientId = pretty_uuid(bytes) unless bytes.nil?
      end

      def messageIdBytes= bytes
        @messageId = pretty_uuid(bytes) unless bytes.nil?
      end

      def read_external des
        read_external_fields des, EXTERNALIZABLE_FIELDS
      end

      private
      def rand_uuid
        [8,4,4,4,12].map {|n| rand_hex_3(n)}.join('-').to_s
      end

      def rand_hex_3(l)
        "%0#{l}x" % rand(1 << l*4)
      end

      def pretty_uuid bytes
        "%08x-%04x-%04x-%04x-%08x%04x" % bytes.string.unpack("NnnnNn")
      end

      def read_external_fields des, fields
        # Read flags
        flags = []
        loop do
          flags << des.source.read(1).unpack('C').first
          break if flags.last < 128
        end

        # Read fields and any remaining unmapped fields in a byte-set
        fields.each_with_index do |list, i|
          list.each_with_index do |name, j|
            if flags[i] & 2**j != 0
              send("#{name}=", des.read_object)
            end
          end

          # Read remaining flags even though we don't recognize them
          # Zero out high bit, as it's the has-next-field marker
          f = (flags[i] & ~128) >> list.length
          while f > 0
            des.read_object if (f & 1) != 0
            f >>= 1
          end
        end
      end
    end

    # Maps to <tt>flex.messaging.messages.RemotingMessage</tt>
    class RemotingMessage < AbstractMessage
      # The name of the service to be called including package name
      attr_accessor :source

      # The name of the method to be called
      attr_accessor :operation

      # The arguments to call the method with
      attr_accessor :parameters

      def initialize
        @clientId = rand_uuid
        @destination = nil
        @messageId = rand_uuid
        @timestamp = Time.new.to_i*100
        @timeToLive = 0
        @headers = {}
        @body = nil
      end
    end

    # Maps to <tt>flex.messaging.messages.AsyncMessage</tt>
    class AsyncMessage < AbstractMessage
      EXTERNALIZABLE_FIELDS = [
        %w[ correlationId correlationIdBytes]
      ]
      attr_accessor :correlationId

      def correlationIdBytes= bytes
        @correlationId = pretty_uuid(bytes) unless bytes.nil?
      end

      def read_external des
        super des
        read_external_fields des, EXTERNALIZABLE_FIELDS
      end
    end

    class AsyncMessageExt < AsyncMessage #:nodoc:
    end

    # Maps to <tt>flex.messaging.messages.CommandMessage</tt>
    class CommandMessage < AsyncMessage
      SUBSCRIBE_OPERATION = 0
      UNSUSBSCRIBE_OPERATION = 1
      POLL_OPERATION = 2
      CLIENT_SYNC_OPERATION = 4
      CLIENT_PING_OPERATION = 5
      CLUSTER_REQUEST_OPERATION = 7
      LOGIN_OPERATION = 8
      LOGOUT_OPERATION = 9
      SESSION_INVALIDATE_OPERATION = 10
      MULTI_SUBSCRIBE_OPERATION = 11
      DISCONNECT_OPERATION = 12
      UNKNOWN_OPERATION = 10000

      EXTERNALIZABLE_FIELDS = [
        %w[ operation ]
      ]
      attr_accessor :operation

      def initialize
        @operation = UNKNOWN_OPERATION
      end

      def read_external des
        super des
        read_external_fields des, EXTERNALIZABLE_FIELDS
      end
    end

    class CommandMessageExt < CommandMessage #:nodoc:
    end

    # Maps to <tt>flex.messaging.messages.AcknowledgeMessage</tt>
    class AcknowledgeMessage < AsyncMessage
      EXTERNALIZABLE_FIELDS = [[]]

      def initialize message=nil
        @clientId = rand_uuid
        @destination = nil
        @messageId = rand_uuid
        @timestamp = Time.new.to_i*100
        @timeToLive = 0
        @headers = {}
        @body = nil

        if message.is_a?(AbstractMessage)
          @correlationId = message.messageId
        end
      end

      def read_external des
        super des
        read_external_fields des, EXTERNALIZABLE_FIELDS
      end
    end

    class AcknowledgeMessageExt < AcknowledgeMessage #:nodoc:
    end

    # Maps to <tt>flex.messaging.messages.ErrorMessage</tt> in AMF3 mode
    class ErrorMessage < AcknowledgeMessage
      # Extended data that will facilitate custom error processing on the client
      attr_accessor :extendedData

      # The fault code for the error, which defaults to the class name of the
      # causing exception
      attr_accessor :faultCode

      # Detailed description of what caused the error
      attr_accessor :faultDetail

      # A simple description of the error
      attr_accessor :faultString

      # Optional "root cause" of the error
      attr_accessor :rootCause

      def initialize message=nil, exception=nil
        super message

        unless exception.nil?
          @e = exception
          @faultCode = @e.class.name
          @faultDetail = @e.backtrace.join("\n")
          @faultString = @e.message
        end
      end

      def encode_amf serializer
        if serializer.version == 0
          data = {
            :faultCode => @faultCode,
            :faultDetail => @faultDetail,
            :faultString => @faultString
          }
          serializer.write_object(data)
        else
          serializer.write_object(self)
        end
      end
    end
  end
end