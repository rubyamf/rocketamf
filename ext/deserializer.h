#include <ruby.h>
#ifdef HAVE_RB_STR_ENCODE
#include <ruby/encoding.h>
#endif

typedef struct {
    int version;
    VALUE class_mapper;
    VALUE src;
    char* stream;
    long pos;
    long size;
    VALUE obj_cache;
    VALUE str_cache;
    VALUE trait_cache;
} AMF_DESERIALIZER;

char des_read_byte(AMF_DESERIALIZER *des);
int des_read_uint16(AMF_DESERIALIZER *des);
long des_read_uint32(AMF_DESERIALIZER *des);
double des_read_double(AMF_DESERIALIZER *des);
int des_read_int(AMF_DESERIALIZER *des);
VALUE des_read_string(AMF_DESERIALIZER *des, long len);
VALUE des_read_sym(AMF_DESERIALIZER *des, long len);
void des_set_src(AMF_DESERIALIZER *des, VALUE src);

VALUE des_deserialize(VALUE self, VALUE ver, VALUE src);