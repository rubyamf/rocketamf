require 'rack'
require 'amf'

module Rack
  class AMF
    APPLICATION_AMF = 'application/x-amf'.freeze

    def call env
      if env['CONTENT_TYPE'] != APPLICATION_AMF
        return [200, {"Content-Type" => "text/plain"}, ["Hello From Rack::AMF"]]
      end

      req = env['rack.input'].read
      ::File.open('request.bin', 'w') {|f| f.write req}
      req_obj = ::AMF.deserializer.new().deserialize_request(req)
      puts req_obj.inspect

      [404, {"Content-Type" => "text/plain"}, [""]]
    end
  end
end