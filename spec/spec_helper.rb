begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end
require 'spec/autorun'

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'rocketamf'

def request_fixture(binary_path)
  data = File.open(File.dirname(__FILE__) + '/fixtures/request/' + binary_path).read
  data.force_encoding("ASCII-8BIT") if data.respond_to?(:force_encoding)
  data
end

def object_fixture(binary_path)
  data = File.open(File.dirname(__FILE__) + '/fixtures/objects/' + binary_path).read
  data.force_encoding("ASCII-8BIT") if data.respond_to?(:force_encoding)
  data
end

def create_request(binary_path)
  RocketAMF::Request.new.populate_from_stream(StringIO.new(request_fixture(binary_path)))
end

# Helper classes
class RubyClass; attr_accessor :baz, :foo; end;
class OtherClass; attr_accessor :bar, :foo; end;