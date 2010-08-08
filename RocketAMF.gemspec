# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{RocketAMF}
  s.version = "0.2.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jacob Henry", "Stephen Augenstein", "Joc O'Connor"]
  s.date = %q{2010-08-08}
  s.email = %q{perl.programmer@gmail.com}
  s.extra_rdoc_files = ["README.rdoc"]
  s.files = ["README.rdoc", "Rakefile", "lib/rocketamf/class_mapping.rb", "lib/rocketamf/constants.rb", "lib/rocketamf/pure/deserializer.rb", "lib/rocketamf/pure/io_helpers.rb", "lib/rocketamf/pure/remoting.rb", "lib/rocketamf/pure/serializer.rb", "lib/rocketamf/pure.rb", "lib/rocketamf/remoting.rb", "lib/rocketamf/values/array_collection.rb", "lib/rocketamf/values/messages.rb", "lib/rocketamf/values/typed_hash.rb", "lib/rocketamf.rb", "spec/amf/class_mapping_spec.rb", "spec/amf/deserializer_spec.rb", "spec/amf/remoting_spec.rb", "spec/amf/serializer_spec.rb", "spec/amf/values/array_collection_spec.rb", "spec/amf/values/messages_spec.rb", "spec/spec_helper.rb", "spec/fixtures/objects/amf0-boolean.bin", "spec/fixtures/objects/amf0-complexEncodedStringArray.bin", "spec/fixtures/objects/amf0-date.bin", "spec/fixtures/objects/amf0-ecma-ordinal-array.bin", "spec/fixtures/objects/amf0-hash.bin", "spec/fixtures/objects/amf0-null.bin", "spec/fixtures/objects/amf0-number.bin", "spec/fixtures/objects/amf0-object.bin", "spec/fixtures/objects/amf0-ref-test.bin", "spec/fixtures/objects/amf0-strict-array.bin", "spec/fixtures/objects/amf0-string.bin", "spec/fixtures/objects/amf0-typed-object.bin", "spec/fixtures/objects/amf0-undefined.bin", "spec/fixtures/objects/amf0-untyped-object.bin", "spec/fixtures/objects/amf0-xmlDoc.bin", "spec/fixtures/objects/amf3-0.bin", "spec/fixtures/objects/amf3-arrayCollection.bin", "spec/fixtures/objects/amf3-arrayRef.bin", "spec/fixtures/objects/amf3-bigNum.bin", "spec/fixtures/objects/amf3-byteArray.bin", "spec/fixtures/objects/amf3-byteArrayRef.bin", "spec/fixtures/objects/amf3-complexEncodedStringArray.bin", "spec/fixtures/objects/amf3-date.bin", "spec/fixtures/objects/amf3-datesRef.bin", "spec/fixtures/objects/amf3-dictionary.bin", "spec/fixtures/objects/amf3-dynObject.bin", "spec/fixtures/objects/amf3-emptyArray.bin", "spec/fixtures/objects/amf3-emptyArrayRef.bin", "spec/fixtures/objects/amf3-emptyDictionary.bin", "spec/fixtures/objects/amf3-emptyStringRef.bin", "spec/fixtures/objects/amf3-encodedStringRef.bin", "spec/fixtures/objects/amf3-false.bin", "spec/fixtures/objects/amf3-graphMember.bin", "spec/fixtures/objects/amf3-hash.bin", "spec/fixtures/objects/amf3-largeMax.bin", "spec/fixtures/objects/amf3-largeMin.bin", "spec/fixtures/objects/amf3-max.bin", "spec/fixtures/objects/amf3-min.bin", "spec/fixtures/objects/amf3-mixedArray.bin", "spec/fixtures/objects/amf3-null.bin", "spec/fixtures/objects/amf3-objRef.bin", "spec/fixtures/objects/amf3-primArray.bin", "spec/fixtures/objects/amf3-string.bin", "spec/fixtures/objects/amf3-stringRef.bin", "spec/fixtures/objects/amf3-symbol.bin", "spec/fixtures/objects/amf3-traitRef.bin", "spec/fixtures/objects/amf3-true.bin", "spec/fixtures/objects/amf3-typedObject.bin", "spec/fixtures/objects/amf3-xml.bin", "spec/fixtures/objects/amf3-xmlDoc.bin", "spec/fixtures/objects/amf3-xmlRef.bin", "spec/fixtures/request/acknowledge-response.bin", "spec/fixtures/request/amf0-error-response.bin", "spec/fixtures/request/commandMessage.bin", "spec/fixtures/request/remotingMessage.bin", "spec/fixtures/request/simple-response.bin", "spec/fixtures/request/unsupportedCommandMessage.bin", "spec/spec.opts"]
  s.homepage = %q{http://github.com/warhammerkid/rocket-amf}
  s.rdoc_options = ["--line-numbers", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Fast AMF serializer/deserializer with remoting request/response wrappers to simplify integration}
  s.test_files = ["spec/amf/class_mapping_spec.rb", "spec/amf/deserializer_spec.rb", "spec/amf/remoting_spec.rb", "spec/amf/serializer_spec.rb", "spec/amf/values/array_collection_spec.rb", "spec/amf/values/messages_spec.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
