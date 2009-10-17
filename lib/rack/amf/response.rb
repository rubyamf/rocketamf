module Rack::AMF
  # Rack specific wrapper around AMF::Response
  class Response
    attr_reader :raw_response

    V = ::AMF::Values

    def initialize request
      @request = request
      @raw_response = ::AMF::Response.new
      @raw_response.amf_version = @request.version == 3 ? 3 : 0 # Can't just copy version because FMS sends version as 1
    end

    # Builds response, iterating over each method call and using the return value
    # as the method call's return value
    #--
    # Iterate over all the sent messages. If they're somthing we can handle, like
    # a command message, then simply add the response message ourselves. If it's
    # a method call, then call the block with the method and args, catching errors
    # for handling. Then create the appropriate response message using the return
    # value of the block as the return value for the method call.
    def each_method_call &block
      raise 'Response already constructed' if @constructed

      @request.messages.each do |m|
        # What's the request body?
        case m.data
        when V::CommandMessage
          # Pings should be responded to with an AcknowledgeMessage built using the ping
          # Everything else is unsupported
          command_msg = m.data
          if command_msg.operation == V::CommandMessage::CLIENT_PING_OPERATION
            response_value = V::AcknowledgeMessage.new(command_msg)
          else
            response_value = V::ErrorMessage.new(Exception.new("CommandMessage #{command_msg.operation} not implemented"), command_msg)
          end
        when V::RemotingMessage
          # Using RemoteObject style message calls
          remoting_msg = m.data
          acknowledge_msg = V::AcknowledgeMessage.new(remoting_msg)
          body = dispatch_call :method => remoting_msg.source+'.'+remoting_msg.operation, :args => remoting_msg.body, :source => remoting_msg, :block => block

          # Response should be the bare ErrorMessage if there was an error
          if body.is_a?(V::ErrorMessage)
            response_value = body
          else
            acknowledge_msg.body = body
            response_value = acknowledge_msg
          end
        else
          # Standard response message
          response_value = dispatch_call :method => m.target_uri, :args => m.data, :source => m, :block => block
        end

        target_uri = m.response_uri
        target_uri += response_value.is_a?(V::ErrorMessage) ? '/onStatus' : '/onResult'
        @raw_response.messages << ::AMF::Message.new(target_uri, '', response_value)
      end

      @constructed = true
    end

    # Return the serialized response as a string
    def to_s
      raw_response.serialize
    end

    private
    def dispatch_call p
      begin
        p[:block].call(p[:method], p[:args])
      rescue Exception => e
        # Create ErrorMessage object using the source message as the base
        V::ErrorMessage.new(p[:source], e)
      end
    end
  end
end