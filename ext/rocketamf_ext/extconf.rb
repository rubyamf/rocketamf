require 'mkmf'

# Disable the native extension by creating an empty Makefile on JRuby
if defined? JRUBY_VERSION
  message "Generating phony Makefile for JRuby so the gem installs"
  mfile = File.join(File.dirname(__FILE__), 'Makefile')
  File.open(mfile, 'w') {|f| f.write dummy_makefile(File.dirname(__FILE__)) }
  exit 0
end

if enable_config("sort-props", false)
  $defs.push("-DSORT_PROPS") unless $defs.include? "-DSORT_PROPS"
end
have_func('rb_str_encode')

create_makefile('rocketamf_ext')