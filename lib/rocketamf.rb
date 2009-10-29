$:.unshift(File.dirname(__FILE__)) unless $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
$:.unshift "#{File.expand_path(File.dirname(__FILE__))}/rocketamf/"

require 'rocketamf/common'

module RocketAMF
  begin
    raise LoadError, 'C extensions not implemented'
  rescue LoadError
    require 'rocketamf/pure'
  end
end