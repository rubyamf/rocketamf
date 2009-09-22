# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rack-amf}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Tony Hillerson", "Stephen Augenstein"]
  s.date = %q{2009-09-27}
  s.email = %q{perl.programmer@gmail.com}
  s.extra_rdoc_files = ["README.txt"]
  s.files = ["README.txt", "Rakefile", "History.txt", "lib/amf/common.rb", "lib/amf/constants.rb", "lib/amf/ext.rb", "lib/amf/pure/deserializer.rb", "lib/amf/pure/serializer.rb", "lib/amf/pure.rb", "lib/amf/request.rb", "lib/amf/version.rb", "lib/amf.rb", "lib/rack/amf/config/default.rb", "lib/rack/amf/config.rb", "lib/rack/amf/context.rb", "lib/rack/amf/core.rb", "lib/rack/amf/headers.rb", "lib/rack/amf/options.rb", "lib/rack/amf/request.rb", "lib/rack/amf/response.rb", "lib/rack/amf.rb", "spec/class_mapper_config_spec.rb", "spec/deserializer_spec.rb", "spec/serializer_spec.rb", "spec/spec_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/warhammerkid/rack-amf}
  s.rdoc_options = ["--line-numbers", "--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{AMF serializer/deserializer and AMF gateway packaged as a rack middleware}
  s.test_files = ["spec/class_mapper_config_spec.rb", "spec/deserializer_spec.rb", "spec/serializer_spec.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<bindata>, [">= 1.0.0"])
    else
      s.add_dependency(%q<bindata>, [">= 1.0.0"])
    end
  else
    s.add_dependency(%q<bindata>, [">= 1.0.0"])
  end
end
