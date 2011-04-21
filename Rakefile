require 'rubygems'
require 'rake'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'spec/rake/spectask'

desc 'Default: run the specs.'
task :default => :spec

# I don't want to depend on bundler, so we do it the bundler way without it
gemspec_path = 'RocketAMF.gemspec'
spec = begin
  eval(File.read(File.join(File.dirname(__FILE__), gemspec_path)), TOPLEVEL_BINDING, gemspec_path)
rescue LoadError => e
  original_line = e.backtrace.find { |line| line.include?(gemspec_path) }
  msg  = "There was a LoadError while evaluating #{gemspec_path}:\n  #{e.message}"
  msg << " from\n  #{original_line}" if original_line
  msg << "\n"
  puts msg
  exit
end

Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--options', 'spec/spec.opts']
end

desc 'Generate documentation for the RocketAMF plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = spec.name
  rdoc.options += spec.rdoc_options
  rdoc.rdoc_files.include(*spec.extra_rdoc_files)
  rdoc.rdoc_files.include("lib") # Don't include ext folder because no one cares
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
  pkg.need_zip = true
end