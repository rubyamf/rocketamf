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
require 'rocketamf/pure/io_helpers' # Just to make sure they get loaded

def request_fixture(binary_path)
  data = File.open(File.dirname(__FILE__) + '/fixtures/request/' + binary_path, "rb").read
  data.force_encoding("ASCII-8BIT") if data.respond_to?(:force_encoding)
  data
end

def object_fixture(binary_path)
  data = File.open(File.dirname(__FILE__) + '/fixtures/objects/' + binary_path, "rb").read
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
class ExternalizableTest
  include RocketAMF::Pure::ReadIOHelpers
  include RocketAMF::Pure::WriteIOHelpers

  attr_accessor :one, :two

  def encode_amf serializer
    serializer.write_object(self, nil, {:class_name => 'ExternalizableTest', :dynamic => false, :externalizable => true, :members => []})
  end

  def read_external des
    @one = read_double(des.source)
    @two = read_double(des.source)
  end

  def write_external ser
    ser.stream << pack_double(@one)
    ser.stream << pack_double(@two)
  end
end