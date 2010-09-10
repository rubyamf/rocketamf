begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end
require 'spec/autorun'

$:.unshift(File.dirname(__FILE__) + '/../ext')
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

def create_envelope(binary_path)
  RocketAMF::Envelope.new.populate_from_stream(StringIO.new(request_fixture(binary_path)))
end

# Helper classes
class RubyClass; attr_accessor :baz, :foo; end;
class OtherClass; attr_accessor :bar, :foo; end;
class ClassMappingTest
  attr_accessor :prop_a
  attr_accessor :prop_b
end
class ClassMappingTest2 < ClassMappingTest
  attr_accessor :prop_c
end
module ANamespace; class TestRubyClass; end; end