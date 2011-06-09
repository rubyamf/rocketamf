#include "deserializer.h"
#include "constants.h"

#define DES_BOUNDS_CHECK(des, i) if(des->pos + (i) > des->size) rb_raise(rb_eRangeError, "reading %ld bytes is beyond end of source: %ld (pos), %ld (size)", (long)(i), des->pos, des->size);

extern VALUE mRocketAMF;
extern VALUE mRocketAMFExt;
extern VALUE cDeserializer;
extern VALUE cStringIO;
extern VALUE sym_class_name;
extern VALUE sym_members;
extern VALUE sym_externalizable;
extern VALUE sym_dynamic;
ID id_get_ruby_obj;
ID id_populate_ruby_obj;

static VALUE des0_deserialize(VALUE self, char type);
static VALUE des3_deserialize(VALUE self);

char des_read_byte(AMF_DESERIALIZER *des) {
    DES_BOUNDS_CHECK(des, 1);
    des->pos++;
    return des->stream[des->pos-1];
}

int des_read_uint16(AMF_DESERIALIZER *des) {
    DES_BOUNDS_CHECK(des, 2);
    const unsigned char *str = des->stream + des->pos;
    des->pos += 2;
    return ((str[0] << 8) | str[1]);
}

long des_read_uint32(AMF_DESERIALIZER *des) {
    DES_BOUNDS_CHECK(des, 4);
    const unsigned char *str = des->stream + des->pos;
    des->pos += 4;
    return ((str[0] << 24) | (str[1] << 16) | (str[2] << 8) | str[3]);
}

/*
 * Read a network double
 */
double des_read_double(AMF_DESERIALIZER *des) {
    DES_BOUNDS_CHECK(des, 8);
    union aligned {
        double dval;
        char cval[8];
    } d;
    const char *str = des->stream + des->pos;
    des->pos +=8;

#ifdef WORDS_BIGENDIAN
    memcpy(d.cval, str, 8);
#else
    d.cval[0] = str[7];
    d.cval[1] = str[6];
    d.cval[2] = str[5];
    d.cval[3] = str[4];
    d.cval[4] = str[3];
    d.cval[5] = str[2];
    d.cval[6] = str[1];
    d.cval[7] = str[0];
#endif
    return d.dval;
}

/*
 * Read an AMF3 style integer
 */
int des_read_int(AMF_DESERIALIZER *des) {
    int result = 0, byte_cnt = 0;
    DES_BOUNDS_CHECK(des, 1);
    char byte =  des->stream[des->pos++];

    while(byte & 0x80 && byte_cnt < 3) {
        result <<= 7;
        result |= byte & 0x7f;
        DES_BOUNDS_CHECK(des, 1);
        byte = des->stream[des->pos++];
        byte_cnt++;
    }

    if (byte_cnt < 3) {
        result <<= 7;
        result |= byte & 0x7F;
    } else {
        result <<= 8;
        result |= byte & 0xff;
    }

    if (result & 0x10000000) {
        result -= 0x20000000;
    }

    return result;
}

/*
 * Read a string and then force the encoding to UTF 8 if running ruby 1.9
 */
VALUE des_read_string(AMF_DESERIALIZER *des, long len) {
    DES_BOUNDS_CHECK(des, len);
    VALUE str = rb_str_new(des->stream + des->pos, len);
#ifdef HAVE_RB_STR_ENCODE
    rb_encoding *utf8 = rb_utf8_encoding();
    rb_enc_associate(str, utf8);
    ENC_CODERANGE_CLEAR(str);
#endif
    des->pos += len;
    return str;
}

/*
 * Because Ruby 1.8 doesn't have a good optimization for looking up symbols from
 * C strings, this function does the lookup without requiring any additional
 * allocations.
 */
VALUE des_read_sym(AMF_DESERIALIZER *des, long len) {
    DES_BOUNDS_CHECK(des, len);
    char end = des->stream[des->pos+len];
    des->stream[des->pos+len] = '\0';
    VALUE sym = ID2SYM(rb_intern(des->stream + des->pos));
    des->stream[des->pos+len] = end;
    des->pos += len;
    return sym;
}

/*
 * Set the source of the amf reader to a StringIO object, creating a new one to
 * wrap the source if it's only a string
 */
void des_set_src(AMF_DESERIALIZER *des, VALUE src) {
    VALUE klass = CLASS_OF(src);
    if(klass == cStringIO) {
        VALUE str = rb_funcall(src, rb_intern("string"), 0);
        des->src = src;
        des->stream = RSTRING_PTR(str);
        des->pos = NUM2LONG(rb_funcall(src, rb_intern("pos"), 0));
        des->size = RSTRING_LEN(str);
    } else if(klass == rb_cString) {
        VALUE args[1] = {src};
        des->src = rb_class_new_instance(1, args, cStringIO);
        des->stream = RSTRING_PTR(src);
        des->pos = 0;
        des->size = RSTRING_LEN(src);
    } else {
        rb_raise(rb_eArgError, "Invalid source type to deserialize from");
    }

    if(des->pos >= des->size) rb_raise(rb_eRangeError, "already at the end of the source");
}

/*
 * Create AMF3 deserializer and copy source data over to it, before calling
 * AMF3 internal deserialize function
 */
static VALUE des0_read_amf3(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);
    des->version = 3;
    des->str_cache = rb_ary_new();
    des->trait_cache = rb_ary_new();
    return des3_deserialize(self);
}

/*
 * Reads an AMF0 hash, with a configurable key reading function - either
 * des_read_string or des_read_sym
 */
static void des0_read_props(VALUE self, VALUE hash, VALUE(*read_key)(AMF_DESERIALIZER*, long)) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    while(1) {
        int len = des_read_uint16(des);
        if(len == 0) {
            des_read_byte(des); // Read type byte
            return;
        } else {
            VALUE key = read_key(des, len);
            char type = des_read_byte(des);
            rb_hash_aset(hash, key, des0_deserialize(self, type));
        }
    }
}

static VALUE des0_read_object(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    // Create object and add to cache
    VALUE obj = rb_funcall(des->class_mapper, id_get_ruby_obj, 1, rb_str_new(NULL, 0));
    rb_ary_push(des->obj_cache, obj);

    // Populate object
    VALUE props = rb_hash_new();
    des0_read_props(self, props, des_read_sym);
    rb_funcall(des->class_mapper, id_populate_ruby_obj, 2, obj, props);

    return obj;
}

static VALUE des0_read_typed_object(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    // Create object and add to cache
    VALUE class_name = des_read_string(des, des_read_uint16(des));
    VALUE obj = rb_funcall(des->class_mapper, id_get_ruby_obj, 1, class_name);
    rb_ary_push(des->obj_cache, obj);

    // Populate object
    VALUE props = rb_hash_new();
    des0_read_props(self, props, des_read_sym);
    rb_funcall(des->class_mapper, id_populate_ruby_obj, 2, obj, props);

    return obj;
}

static VALUE des0_read_hash(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);
    des_read_uint32(des); // Hash size, but there's no optimization I can perform with this
    VALUE obj = rb_hash_new();
    rb_ary_push(des->obj_cache, obj);
    des0_read_props(self, obj, des_read_string);
    return obj;
}

static VALUE des0_read_array(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    // Limit size of pre-allocation to force remote user to actually send data,
    // rather than just sending a size of 2**32-1 and nothing afterwards to
    // crash the server
    long len = des_read_uint32(des);
    VALUE ary = rb_ary_new2(len < MAX_ARRAY_PREALLOC ? len : MAX_ARRAY_PREALLOC);
    rb_ary_push(des->obj_cache, ary);

    long i;
    for(i = 0; i < len; i++) {
        rb_ary_push(ary, des0_deserialize(self, des_read_byte(des)));
    }

    return ary;
}

static VALUE des0_read_time(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);
    double milli = des_read_double(des);
    des_read_uint16(des); // Timezone - unused
    time_t sec = milli/1000.0;
    time_t micro = (milli-sec*1000)*1000;
    return rb_time_new(sec, micro);
}

/*
 * Internal C deserialize call. Takes deserializer and a char for the type
 * marker.
 */
static VALUE des0_deserialize(VALUE self, char type) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    long tmp;
    VALUE ret = Qnil;
    switch(type) {
        case AMF0_STRING_MARKER:
            ret = des_read_string(des, des_read_uint16(des));
            break;
        case AMF0_AMF3_MARKER:
            ret = des0_read_amf3(self);
            break;
        case AMF0_NUMBER_MARKER:
            ret = rb_float_new(des_read_double(des));
            break;
        case AMF0_BOOLEAN_MARKER:
            ret = des_read_byte(des) == 0 ? Qfalse : Qtrue;
            break;
        case AMF0_NULL_MARKER:
        case AMF0_UNDEFINED_MARKER:
        case AMF0_UNSUPPORTED_MARKER:
            ret = Qnil;
            break;
        case AMF0_OBJECT_MARKER:
            ret = des0_read_object(self);
            break;
        case AMF0_TYPED_OBJECT_MARKER:
            ret = des0_read_typed_object(self);
            break;
        case AMF0_HASH_MARKER:
            ret = des0_read_hash(self);
            break;
        case AMF0_STRICT_ARRAY_MARKER:
            ret = des0_read_array(self);
            break;
        case AMF0_REFERENCE_MARKER:
            tmp = des_read_uint16(des);
            if(tmp >= RARRAY_LEN(des->obj_cache)) rb_raise(rb_eRangeError, "reference index beyond end");
            ret = RARRAY_PTR(des->obj_cache)[tmp];
            break;
        case AMF0_DATE_MARKER:
            ret = des0_read_time(self);
            break;
        case AMF0_XML_MARKER:
        case AMF0_LONG_STRING_MARKER:
            ret = des_read_string(des, des_read_uint32(des));
            break;
        default:
            rb_raise(rb_eRuntimeError, "Not supported: %d", type);
            break;
    }

    return ret;
}

static VALUE des3_read_string(AMF_DESERIALIZER *des) {
    int header = des_read_int(des);
    if((header & 1) == 0) {
        header >>= 1;
        if(header >= RARRAY_LEN(des->str_cache)) rb_raise(rb_eRangeError, "str reference index beyond end");
        return RARRAY_PTR(des->str_cache)[header];
    } else {
        VALUE str = des_read_string(des, header >> 1);
        if(RSTRING_LEN(str) > 0) rb_ary_push(des->str_cache, str);
        return str;
    }
}

/*
 * Same as des3_read_string, but XML uses the object cache, rather than the
 * string cache
 */
static VALUE des3_read_xml(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    int header = des_read_int(des);
    if((header & 1) == 0) {
        header >>= 1;
        if(header >= RARRAY_LEN(des->obj_cache)) rb_raise(rb_eRangeError, "obj reference index beyond end");
        return RARRAY_PTR(des->obj_cache)[header];
    } else {
        VALUE str = des_read_string(des, header >> 1);
        if(RSTRING_LEN(str) > 0) rb_ary_push(des->obj_cache, str);
        return str;
    }
}

static VALUE des3_read_object(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    int header = des_read_int(des);
    if((header & 1) == 0) {
        header >>= 1;
        if(header >= RARRAY_LEN(des->obj_cache)) rb_raise(rb_eRangeError, "obj reference index beyond end");
        return RARRAY_PTR(des->obj_cache)[header];
    } else {
        VALUE externalizable, dynamic, members, class_name, traits;
        long i, members_len;

        // Parse traits
        header >>= 1;
        if((header & 1) == 0) {
            header >>= 1;
            if(header >= RARRAY_LEN(des->trait_cache)) rb_raise(rb_eRangeError, "trait reference index beyond end");
            traits = RARRAY_PTR(des->trait_cache)[header];
            externalizable = rb_hash_aref(traits, sym_externalizable);
            dynamic = rb_hash_aref(traits, sym_dynamic);
            members = rb_hash_aref(traits, sym_members);
            members_len = members == Qnil ? 0 : RARRAY_LEN(members);
            class_name = rb_hash_aref(traits, sym_class_name);
        } else {
            externalizable = (header & 2) != 0 ? Qtrue : Qfalse;
            dynamic = (header & 4) != 0 ? Qtrue : Qfalse;
            members_len = header >> 3;
            class_name = des3_read_string(des);

            members = rb_ary_new2(members_len);
            for(i = 0; i < members_len; i++) rb_ary_push(members, des3_read_string(des));

            traits = rb_hash_new();
            rb_hash_aset(traits, sym_externalizable, externalizable);
            rb_hash_aset(traits, sym_dynamic, dynamic);
            rb_hash_aset(traits, sym_members, members);
            rb_hash_aset(traits, sym_class_name, class_name);
            rb_ary_push(des->trait_cache, traits);
        }

        // Optimization for deserializing ArrayCollection
        if(strcmp(RSTRING_PTR(class_name), "flex.messaging.io.ArrayCollection") == 0) {
            VALUE arr = des3_deserialize(self); // Adds ArrayCollection array to object cache automatically
            rb_ary_push(des->obj_cache, arr); // Add again for ArrayCollection source array
            return arr;
        }

        VALUE obj = rb_funcall(des->class_mapper, id_get_ruby_obj, 1, class_name);
        rb_ary_push(des->obj_cache, obj);

        if(externalizable == Qtrue) {
            rb_funcall(des->src, rb_intern("pos="), 1, LONG2NUM(des->pos)); // Update source StringIO pos
            rb_funcall(obj, rb_intern("read_external"), 1, self);
            des->pos = NUM2LONG(rb_funcall(des->src, rb_intern("pos"), 0)); // Update from source
            return obj;
        }

        VALUE props = rb_hash_new();
        for(i = 0; i < members_len; i++) {
            rb_hash_aset(props, rb_str_intern(RARRAY_PTR(members)[i]), des3_deserialize(self));
        }

        VALUE dynamic_props = Qnil;
        if(dynamic == Qtrue) {
            dynamic_props = rb_hash_new();
            while(1) {
                VALUE key = des3_read_string(des);
                if(RSTRING_LEN(key) == 0) break;
                rb_hash_aset(dynamic_props, rb_str_intern(key), des3_deserialize(self));
            }
        }

        rb_funcall(des->class_mapper, id_populate_ruby_obj, 3, obj, props, dynamic_props);

        return obj;
    }
}

static VALUE des3_read_array(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    int i;
    int header = des_read_int(des);
    if((header & 1) == 0) {
        header >>= 1;
        if(header >= RARRAY_LEN(des->obj_cache)) rb_raise(rb_eRangeError, "obj reference index beyond end");
        return RARRAY_PTR(des->obj_cache)[header];
    } else {
        header >>= 1;
        VALUE obj;
        VALUE key = des3_read_string(des);
        if(key == Qnil) rb_raise(rb_eRangeError, "key is Qnil");
        if(RSTRING_LEN(key) != 0) {
            obj = rb_hash_new();
            rb_ary_push(des->obj_cache, obj);
            while(RSTRING_LEN(key) != 0) {
                rb_hash_aset(obj, key, des3_deserialize(self));
                key = des3_read_string(des);
            }
            for(i = 0; i < header; i++) {
                rb_hash_aset(obj, rb_fix2str(INT2FIX(i), 10), des3_deserialize(self));
            }
        } else {
            // Limit size of pre-allocation to force remote user to actually send data,
            // rather than just sending a size of 2**32-1 and nothing afterwards to
            // crash the server
            obj = rb_ary_new2(header < MAX_ARRAY_PREALLOC ? header : MAX_ARRAY_PREALLOC);
            rb_ary_push(des->obj_cache, obj);
            for(i = 0; i < header; i++) {
                rb_ary_push(obj, des3_deserialize(self));
            }
        }
        return obj;
    }
}

static VALUE des3_read_time(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    int header = des_read_int(des);
    if((header & 1) == 0) {
        header >>= 1;
        if(header >= RARRAY_LEN(des->obj_cache)) rb_raise(rb_eRangeError, "obj reference index beyond end");
        return RARRAY_PTR(des->obj_cache)[header];
    } else {
        double milli = des_read_double(des);
        time_t sec = milli/1000.0;
        time_t micro = (milli-sec*1000)*1000;
        VALUE time = rb_time_new(sec, micro);
        rb_ary_push(des->obj_cache, time);
        return time;
    }
}

static VALUE des3_read_byte_array(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    int header = des_read_int(des);
    if((header & 1) == 0) {
        header >>= 1;
        if(header >= RARRAY_LEN(des->obj_cache)) rb_raise(rb_eRangeError, "obj reference index beyond end");
        return RARRAY_PTR(des->obj_cache)[header];
    } else {
        header >>= 1;
        VALUE args[1] = {des_read_string(des, header)};
#ifdef HAVE_RB_STR_ENCODE
        // Need to force encoding to ASCII-8BIT
        rb_encoding *ascii = rb_ascii8bit_encoding();
        rb_enc_associate(args[0], ascii);
        ENC_CODERANGE_CLEAR(args[0]);
#endif
        VALUE ba = rb_class_new_instance(1, args, cStringIO);
        rb_ary_push(des->obj_cache, ba);
        return ba;
    }
}

static VALUE des3_read_dict(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    int header = des_read_int(des);
    if((header & 1) == 0) {
        header >>= 1;
        if(header >= RARRAY_LEN(des->obj_cache)) rb_raise(rb_eRangeError, "obj reference index beyond end");
        return RARRAY_PTR(des->obj_cache)[header];
    } else {
        header >>= 1;

        VALUE dict = rb_hash_new();
        rb_ary_push(des->obj_cache, dict);

        des_read_int(des); // Skip - don't know what it does

        int i;
        for(i = 0; i < header; i++) {
            VALUE key = des3_deserialize(self);
            VALUE val = des3_deserialize(self);
            rb_hash_aset(dict, key, val);
        }

        return dict;
    }
}

/*
 * Internal deserialize call - unlike des0_deserialize, it reads the type
 * itself, due to minor changes in the specs that make that modification
 * unnecessary.
 */
static VALUE des3_deserialize(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    char type = des_read_byte(des);
    VALUE ret = Qnil;
    switch(type) {
        case AMF3_UNDEFINED_MARKER:
        case AMF3_NULL_MARKER:
            ret = Qnil;
            break;
        case AMF3_FALSE_MARKER:
            ret = Qfalse;
            break;
        case AMF3_TRUE_MARKER:
            ret = Qtrue;
            break;
        case AMF3_INTEGER_MARKER:
            ret = INT2FIX(des_read_int(des));
            break;
        case AMF3_DOUBLE_MARKER:
            ret = rb_float_new(des_read_double(des));
            break;
        case AMF3_STRING_MARKER:
            ret = des3_read_string(des);
            break;
        case AMF3_ARRAY_MARKER:
            ret = des3_read_array(self);
            break;
        case AMF3_OBJECT_MARKER:
            ret = des3_read_object(self);
            break;
        case AMF3_DATE_MARKER:
            ret = des3_read_time(self);
            break;
        case AMF3_XML_DOC_MARKER:
        case AMF3_XML_MARKER:
            ret = des3_read_xml(self);
            break;
        case AMF3_BYTE_ARRAY_MARKER:
            ret = des3_read_byte_array(self);
            break;
        case AMF3_DICT_MARKER:
            ret = des3_read_dict(self);
            break;
        default:
            rb_raise(rb_eRuntimeError, "Not supported: %d", type);
            break;
    }

    return ret;
}

/*
 * Mark the reader and its source. If caches are populated mark them as well.
 */
static void des_mark(AMF_DESERIALIZER *des) {
    if(!des) return;
    rb_gc_mark(des->class_mapper);
    rb_gc_mark(des->src);
    if(des->obj_cache) rb_gc_mark(des->obj_cache);
    if(des->str_cache) rb_gc_mark(des->str_cache);
    if(des->trait_cache) rb_gc_mark(des->trait_cache);
}

/*
 * Free the reader. Don't need to free anything but the struct because we didn't
 * alloc anything - source is from the ruby source object.
 */
static void des_free(AMF_DESERIALIZER *des) {
    xfree(des);
}

/*
 * Create new struct and wrap with class
 */
static VALUE des_alloc(VALUE klass) {
    AMF_DESERIALIZER *des = ALLOC(AMF_DESERIALIZER);
    memset(des, 0, sizeof(AMF_DESERIALIZER));
    return Data_Wrap_Struct(klass, des_mark, des_free, des);
}

/*
 * Initializer
 */
static VALUE des_initialize(VALUE self, VALUE class_mapper) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);
    des->class_mapper = class_mapper;
    return self;
}

/*
 * call-seq:
 *   ser.stream => StringIO
 *
 * Returns the source that the deserializer is reading from
 */
static VALUE des_source(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);
    return des->src;
}

/*
 * call-seq:
 *   des.deserialize(amf_ver, str) => obj
 *   des.deserialize(amf_ver, StringIO) => obj
 *
 * Deserialize the string or StringIO from AMF to a ruby object.
 */
VALUE des_deserialize(VALUE self, VALUE ver, VALUE src) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    // Process version
    int int_ver = FIX2INT(ver);
    if(int_ver != 0 && int_ver != 3) rb_raise(rb_eArgError, "unsupported version %d", int_ver);
    des->version = int_ver;

    // Process source
    if(src != Qnil) {
        des_set_src(des, src);
    } else if(!des->src) {
        rb_raise(rb_eArgError, "Missing deserialization source");
    }

    // Deserialize from source
    VALUE ret;
    if(des->version == 0) {
        des->obj_cache = rb_ary_new();
        ret = des0_deserialize(self, des_read_byte(des));
    } else {
        des->obj_cache = rb_ary_new();
        des->str_cache = rb_ary_new();
        des->trait_cache = rb_ary_new();
        ret = des3_deserialize(self);
    }

    // Update source position
    rb_funcall(des->src, rb_intern("pos="), 1, LONG2NUM(des->pos)); // Update source StringIO pos

    return ret;
}

/*
 * call-seq:
 *   des.read_object => obj
 *
 * Reads an object from the deserializer's stream and returns it.
 */
VALUE des_read_object(VALUE self) {
    AMF_DESERIALIZER *des;
    Data_Get_Struct(self, AMF_DESERIALIZER, des);

    // Update internal pos from source in case they've modified it
    des->pos = NUM2LONG(rb_funcall(des->src, rb_intern("pos"), 0));

    // Deserialize
    VALUE ret;
    if(des->version == 0) {
        ret = des0_deserialize(self, des_read_byte(des));
    } else {
        ret = des3_deserialize(self);
    }

    // Update source position
    rb_funcall(des->src, rb_intern("pos="), 1, LONG2NUM(des->pos)); // Update source StringIO pos

    return ret;
}

void Init_rocket_amf_deserializer() {
    // Define Deserializer
    cDeserializer = rb_define_class_under(mRocketAMFExt, "Deserializer", rb_cObject);
    rb_define_alloc_func(cDeserializer, des_alloc);
    rb_define_method(cDeserializer, "initialize", des_initialize, 1);
    rb_define_method(cDeserializer, "source", des_source, 0);
    rb_define_method(cDeserializer, "deserialize", des_deserialize, 2);
    rb_define_method(cDeserializer, "read_object", des_read_object, 0);

    // Get refs to commonly used symbols and ids
    id_get_ruby_obj = rb_intern("get_ruby_obj");
    id_populate_ruby_obj = rb_intern("populate_ruby_obj");
}