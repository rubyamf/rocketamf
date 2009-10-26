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

desc 'Generate documentation for the rubyamf plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Rack AMF'
  rdoc.options << '--line-numbers' << '--main' << 'README.rdoc'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

spec = Gem::Specification.new do |s|
  s.name    = 'rack-amf'
  s.version = '0.0.4'
  s.summary = 'AMF serializer/deserializer and AMF gateway packaged as a rack middleware'

  s.files        = FileList['README.rdoc', 'Rakefile', 'lib/**/*.rb', 'spec/**/*.rb', 'spec/**/*.bin', 'spec/spec.opts']
  s.require_path = 'lib'
  s.test_files   = Dir[*['spec/**/*_spec.rb']]

  s.has_rdoc         = true
  s.extra_rdoc_files = ['README.rdoc']
  s.rdoc_options     = ['--line-numbers', '--main', 'README.rdoc']

  s.authors  = ['Tony Hillerson', 'Stephen Augenstein']
  s.email    = 'perl.programmer@gmail.com'
  s.homepage = 'http://github.com/warhammerkid/rack-amf'

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