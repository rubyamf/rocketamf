# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name    = 'RocketAMF'
  s.version = '1.0.0'
  s.summary = 'Fast AMF serializer/deserializer with remoting request/response wrappers to simplify integration'

  s.files         = Dir[*['README.rdoc', 'Rakefile', 'lib/**/*.rb', 'spec/**/*.{rb,bin,opts}', 'ext/*.{c,h,rb}']]
  s.require_paths = ["lib", "ext"]
  s.extensions    = ["ext/extconf.rb"]
  s.test_files    = Dir[*['spec/**/*_spec.rb']]

  s.has_rdoc         = true
  s.extra_rdoc_files = ['README.rdoc']
  s.rdoc_options     = ['--line-numbers', '--main', 'README.rdoc']

  s.authors  = ['Jacob Henry', 'Stephen Augenstein', "Joc O'Connor"]
  s.email    = 'perl.programmer@gmail.com'
  s.homepage = 'http://github.com/rubyamf/rocketamf'

  s.platform = Gem::Platform::RUBY
end