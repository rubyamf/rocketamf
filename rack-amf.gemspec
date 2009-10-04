# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rack-amf}
  s.version = "0.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Tony Hillerson", "Stephen Augenstein"]
  s.date = %q{2009-10-04}
  s.email = %q{perl.programmer@gmail.com}
  s.extra_rdoc_files = ["README.rdoc"]
  s.files = ["README.rdoc", "Rakefile", "lib/amf/class_mapping.rb", "lib/amf/common.rb", "lib/amf/constants.rb", "lib/amf/pure/deserializer.rb", "lib/amf/pure/io_helpers.rb", "lib/amf/pure/remoting.rb", "lib/amf/pure/serializer.rb", "lib/amf/pure.rb", "lib/amf/values/array_collection.rb", "lib/amf/values/messages.rb", "lib/amf/values/typed_hash.rb", "lib/amf/version.rb", "lib/amf.rb", "lib/rack/amf/application.rb", "lib/rack/amf/request.rb", "lib/rack/amf/response.rb", "lib/rack/amf/service_manager.rb", "lib/rack/amf.rb", "spec/amf/class_mapping_set_spec.rb", "spec/amf/class_mapping_spec.rb", "spec/amf/deserializer_spec.rb", "spec/amf/remoting_spec.rb", "spec/amf/serializer_spec.rb", "spec/amf/values/array_collection_spec.rb", "spec/amf/values/messages_spec.rb", "spec/rack/request_spec.rb", "spec/rack/response_spec.rb", "spec/rack/service_manager_spec.rb", "spec/spec_helper.rb"]
  s.homepage = %q{http://github.com/warhammerkid/rack-amf}
  s.rdoc_options = ["--line-numbers", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{AMF serializer/deserializer and AMF gateway packaged as a rack middleware}
  s.test_files = ["spec/amf/class_mapping_set_spec.rb", "spec/amf/class_mapping_spec.rb", "spec/amf/deserializer_spec.rb", "spec/amf/remoting_spec.rb", "spec/amf/serializer_spec.rb", "spec/amf/values/array_collection_spec.rb", "spec/amf/values/messages_spec.rb", "spec/rack/request_spec.rb", "spec/rack/response_spec.rb", "spec/rack/service_manager_spec.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
