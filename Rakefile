require 'rubygems'
require 'rake'
require 'rake/rdoctask'
require 'rake/gempackagetask'

require 'spec/rake/spectask'

desc 'Default: run the specs.'
task :default => :spec

Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--options', 'spec/spec.opts']
end

desc 'Generate documentation for the RocketAMF plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'RocketAMF'
  rdoc.options << '--line-numbers' << '--main' << 'README.rdoc'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

spec = Gem::Specification.new do |s|
  s.name    = 'RocketAMF'
  s.version = '0.2.1'
  s.summary = 'Fast AMF serializer/deserializer with remoting request/response wrappers to simplify integration'

  s.files        = FileList['README.rdoc', 'Rakefile', 'lib/**/*.rb', 'spec/**/*.{rb,bin,opts}', 'ext/*.{c,h,rb}']
  s.require_path = 'lib'
  s.extensions   = ["ext/extconf.rb"]
  s.test_files   = Dir[*['spec/**/*_spec.rb']]

  s.has_rdoc         = true
  s.extra_rdoc_files = ['README.rdoc']
  s.rdoc_options     = ['--line-numbers', '--main', 'README.rdoc']

  s.authors  = ['Jacob Henry', 'Stephen Augenstein', "Joc O'Connor"]
  s.email    = 'perl.programmer@gmail.com'
  s.homepage = 'http://github.com/warhammerkid/rocket-amf'

  s.platform = Gem::Platform::RUBY
end

Rake::GemPackageTask.new spec do |pkg|
  pkg.need_tar = true
  pkg.need_zip = true
end

desc 'Generate a gemspec file'
task :gemspec do
  File.open("#{spec.name}.gemspec", 'w') do |f|
    f.write spec.to_ruby
  end
end