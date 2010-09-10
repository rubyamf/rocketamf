require 'mkmf'

if enable_config("sort-props", false)
  $defs.push("-DSORT_PROPS") unless $defs.include? "-DSORT_PROPS"
end
have_func('rb_str_encode')

create_makefile('rocketamf_ext')