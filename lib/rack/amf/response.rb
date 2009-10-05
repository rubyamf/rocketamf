module Rack::AMF
  class Response
    attr_reader :raw_response

    def initialize request
      @request = request
      @raw_response = ::AMF::Response.new
      @raw_response.amf_version = @request.version == 3 ? 3 : 0 # Can't just copy version because FMS sends version as 1
    end

    # Builds response, iterating over each method call and using the return value
    # as the method call's return value
    def each_method_call &block
      raise 'Response already constructed' if @constructed

      @request.messages.each do |m|
        target_uri = m.response_uri

        rd = m.data
        if rd.is_a?(::AMF::Values::CommandMessage)
          if rd.operation == ::AMF::Values::CommandMessage::CLIENT_PING_OPERATION
            data = ::AMF::Values::AcknowledgeMessage.new(rd)
          else
            data == ::AMF::Values::ErrorMessage.new(Exception.new("CommandMessage #{rd.operation} not implemented"), rd)
          end
        elsif rd.is_a?(::AMF::Values::RemotingMessage)
          am = ::AMF::Values::AcknowledgeMessage.new(rd)
          body = dispatch_call(rd.source+'.'+rd.operation, rd.body, rd, block)
          if body.is_a?(::AMF::Values::ErrorMessage)
            data = body
          else
            am.body = body
            data = am
          end
        else
          data = dispatch_call(m.target_uri, rd, m, block)
        end

        target_uri += data.is_a?(::AMF::Values::ErrorMessage) ? '/onStatus' : '/onResult'
        @raw_response.messages << ::AMF::Message.new(target_uri, '', data)
      end

      @constructed = true
    end

    def to_s
      raw_response.serialize
    end

    private
    def dispatch_call method, args, source_message, handler
      begin
        handler.call(method, args)
      rescue Exception => e
        ::AMF::Values::ErrorMessage.new(source_message, e)
      end
    end
  end
end