module RocketAMF
  # Container for the AMF request.
  class Request
    attr_reader :amf_version, :headers, :messages

    def initialize
      @amf_version = 0
      @headers = []
      @messages = []
    end

    # Populates the request from the given stream or string. Returns self for easy
    # chaining
    #
    # Example:
    #
    #    req = RocketAMF::Request.new.populate_from_stream(env['rack.input'].read)
    #--
    # Implemented in pure/remoting.rb RocketAMF::Pure::Request
    def populate_from_stream stream
      raise AMFError, 'Must load "rocketamf/pure"'
    end
  end

  # Container for the response of the AMF call. Includes serialization and request
  # handling code.
  class Response
    attr_accessor :amf_version, :headers, :messages

    def initialize
      @amf_version = 0
      @headers = []
      @messages = []
    end

    # Serializes the response to a string and returns it.
    #--
    # Implemented in pure/remoting.rb RocketAMF::Pure::Response
    def serialize
      raise AMFError, 'Must load "rocketamf/pure"'
    end

    # Builds response from the request, iterating over each method call and using
    # the return value as the method call's return value
    #--
    # Iterate over all the sent messages. If they're somthing we can handle, like
    # a command message, then simply add the response message ourselves. If it's
    # a method call, then call the block with the method and args, catching errors
    # for handling. Then create the appropriate response message using the return
    # value of the block as the return value for the method call.
    def each_method_call request, &block
      raise 'Response already constructed' if @constructed

      # Set version from response
      # Can't just copy version because FMS sends version as 1
      @amf_version = request.amf_version == 3 ? 3 : 0 

      request.messages.each do |m|
        # What's the request body?
        case m.data
        when Values::CommandMessage
          # Pings should be responded to with an AcknowledgeMessage built using the ping
          # Everything else is unsupported
          command_msg = m.data
          if command_msg.operation == Values::CommandMessage::CLIENT_PING_OPERATION
            response_value = Values::AcknowledgeMessage.new(command_msg)
          else
            response_value = Values::ErrorMessage.new(Exception.new("CommandMessage #{command_msg.operation} not implemented"), command_msg)
          end
        when Values::RemotingMessage
          # Using RemoteObject style message calls
          remoting_msg = m.data
          acknowledge_msg = Values::AcknowledgeMessage.new(remoting_msg)
          body = dispatch_call :method => remoting_msg.source+'.'+remoting_msg.operation, :args => remoting_msg.body, :source => remoting_msg, :block => block

          # Response should be the bare ErrorMessage if there was an error
          if body.is_a?(Values::ErrorMessage)
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
        target_uri += response_value.is_a?(Values::ErrorMessage) ? '/onStatus' : '/onResult'
        @messages << ::RocketAMF::Message.new(target_uri, '', response_value)
      end

      @constructed = true
    end

    # Return the serialized response as a string
    def to_s
      serialize
    end

    private
    def dispatch_call p
      begin
        p[:block].call(p[:method], p[:args])
      rescue Exception => e
        # Create ErrorMessage object using the source message as the base
        Values::ErrorMessage.new(p[:source], e)
      end
    end
  end

  # RocketAMF::Request or RocketAMF::Response header
  class Header
    attr_accessor :name, :must_understand, :data

    def initialize name, must_understand, data
      @name = name
      @must_understand = must_understand
      @data = data
    end
  end

  # RocketAMF::Request or RocketAMF::Response message
  class Message
    attr_accessor :target_uri, :response_uri, :data

    def initialize target_uri, response_uri, data
      @target_uri = target_uri
      @response_uri = response_uri
      @data = data
    end
  end
end