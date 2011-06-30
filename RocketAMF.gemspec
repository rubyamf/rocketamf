# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name    = 'RocketAMF'
  s.version = '1.0.0'
  s.platform = Gem::Platform::RUBY
  s.authors  = ['Jacob Henry', 'Stephen Augenstein', "Joc O'Connor"]
  s.email    = ['perl.programmer@gmail.com']
  s.homepage = 'http://github.com/rubyamf/rocketamf'
  s.summary = 'Fast AMF serializer/deserializer with remoting request/response wrappers to simplify integration'

  s.files         = Dir[*['README.rdoc', 'benchmark.rb', 'RocketAMF.gemspec', 'Rakefile', 'lib/**/*.rb', 'spec/**/*.{rb,bin,opts}', 'ext/**/*.{c,h,rb}']]
  s.test_files    = Dir[*['spec/**/*_spec.rb']]
  s.extensions    = Dir[*["ext/**/extconf.rb"]]
  s.require_paths = ["lib"]

  s.has_rdoc         = true
  s.extra_rdoc_files = ['README.rdoc']
  s.rdoc_options     = ['--line-numbers', '--main', 'README.rdoc']
end