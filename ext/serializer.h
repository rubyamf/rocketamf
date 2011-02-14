#include <ruby.h>
#include <ruby/st.h>
#ifdef HAVE_RB_STR_ENCODE
#include <ruby/encoding.h>
#endif

typedef struct {
    int version;
    VALUE stream;
    long depth;
    st_table* str_cache;
    long str_index;
    st_table* trait_cache;
    long trait_index;
    st_table* obj_cache;
    long obj_index;
} AMF_SERIALIZER;

void ser_write_byte(AMF_SERIALIZER *ser, char byte);
void ser_write_int(AMF_SERIALIZER *ser, int num);
void ser_write_uint16(AMF_SERIALIZER *ser, long num);
void ser_write_uint32(AMF_SERIALIZER *ser, long num);
void ser_write_double(AMF_SERIALIZER *ser, double num);
void ser_get_string(VALUE obj, VALUE encode, char** str, long* len);

VALUE ser_serialize(VALUE self, VALUE ver, VALUE obj);