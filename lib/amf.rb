$:.unshift(File.dirname(__FILE__)) unless $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
$:.unshift "#{File.expand_path(File.dirname(__FILE__))}/amf/"

require 'rubygems'
require 'amf/common'

gem 'bindata', '>= 1.0.0'

module AMF
  require 'amf/version'
  
  begin
    # change to test c extension
    #require 'amf/ext'
    require 'amf/pure'
  rescue LoadError
    require 'amf/pure'
  end

  AMF_LOADED = true
end