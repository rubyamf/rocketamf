module AMF
  module Values #:nodoc:
    # Base class for all special AS3 response messages. Maps to
    # <tt>flex.messaging.messages.AbstractMessage</tt>
    class AbstractMessage
      attr_accessor :clientId
      attr_accessor :destination
      attr_accessor :messageId
      attr_accessor :timestamp
      attr_accessor :timeToLive
      attr_accessor :headers
      attr_accessor :body

      protected
      def rand_uuid
        [8,4,4,4,12].map {|n| rand_hex_3(n)}.join('-').to_s
      end

      def rand_hex_3(l)
        "%0#{l}x" % rand(1 << l*4)
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
      attr_accessor :correlationId
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

      attr_accessor :operation

      def initialize
        @operation = UNKNOWN_OPERATION
      end
    end

    # Maps to <tt>flex.messaging.messages.AcknowledgeMessage</tt>
    class AcknowledgeMessage < AsyncMessage
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

      def initialize message, exception
        super message

        @e = exception
        @faultCode = @e.class.name
        @faultDetail = @e.backtrace.join("\n")
        @faultString = @e.message
      end

      def to_amf serializer
        stream = ""
        if serializer.version == 0
          data = {
            :faultCode => @faultCode,
            :faultDetail => @faultDetail,
            :faultString => @faultString
          }
          serializer.write_hash(data, stream)
        else
          serializer.write_object(self, stream)
        end
        stream
      end
    end
  end
end