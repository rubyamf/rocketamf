begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end
require 'spec/autorun'

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'amf'

def request_fixture(binary_path)
  File.open(File.dirname(__FILE__) + '/fixtures/request/' + binary_path).read
end

def object_fixture(binary_path)
  File.open(File.dirname(__FILE__) + '/fixtures/objects/' + binary_path).read
end

def create_request(binary_path)
  AMF::Request.new.populate_from_stream(StringIO.new(request_fixture(binary_path)))
end

# Add reset support to ClassMapping
module AMF
  class ClassMapping
    def reset
      @mappings = nil
    end
  end
end