#include "serializer.h"
#include "constants.h"
#include "utility.h"

extern VALUE mRocketAMF;
extern VALUE mRocketAMFExt;
extern VALUE cSerializer;
extern VALUE cAMF3Serializer;
extern VALUE cStringIO;
extern VALUE cDate;
extern VALUE cDateTime;
extern VALUE sym_class_name;
extern VALUE sym_members;
extern VALUE sym_externalizable;
extern VALUE sym_dynamic;
VALUE cArrayCollection;
ID id_size;
ID id_haskey;
ID id_encode_amf;
ID id_is_array_collection;
ID id_use_array_collection;
ID id_get_as_class_name;
ID id_props_for_serialization;
ID id_utc;
ID id_to_f;

/*
 * Mark the stream
 */
static void ser_mark(AMF_SERIALIZER *ser) {
    if(!ser) return;
    rb_gc_mark(ser->stream);
}

/*
 * Free cache tables, stream and the struct itself
 */
static void ser_free(AMF_SERIALIZER *ser) {
    if(ser->str_cache) st_free_table(ser->str_cache);
    if(ser->trait_cache) st_free_table(ser->trait_cache);
    if(ser->obj_cache) st_free_table(ser->obj_cache);
    xfree(ser);
}

/*
 * Create new struct and wrap with class
 */
static VALUE ser_alloc(VALUE klass) {
    // Allocate struct
    AMF_SERIALIZER *ser = ALLOC(AMF_SERIALIZER);
    memset(ser, 0, sizeof(AMF_SERIALIZER));

    // Initialize stream
    ser->stream = rb_str_buf_new(0);

    return Data_Wrap_Struct(klass, ser_mark, ser_free, ser);
}

void ser_write_byte(AMF_SERIALIZER *ser, char byte) {
    char bytes[2] = {byte, '\0'};
    rb_str_buf_cat(ser->stream, bytes, 1);
}

void ser_write_int(AMF_SERIALIZER *ser, int num) {
    char tmp[4];
    int tmp_len;

    num &= 0x1fffffff;
    if (num < 0x80) {
        tmp_len = 1;
        tmp[0] = num;
    } else if (num < 0x4000) {
        tmp_len = 2;
        tmp[0] = (num >> 7 & 0x7f) | 0x80;
        tmp[1] = num & 0x7f;
    } else if (num < 0x200000) {
        tmp_len = 3;
        tmp[0] = (num >> 14 & 0x7f) | 0x80;
        tmp[1] = (num >> 7 & 0x7f) | 0x80;
        tmp[2] = num & 0x7f;
    } else if (num < 0x40000000) {
        tmp_len = 4;
        tmp[0] = (num >> 22 & 0x7f) | 0x80;
        tmp[1] = (num >> 15 & 0x7f) | 0x80;
        tmp[2] = (num >> 8 & 0x7f) | 0x80;
        tmp[3] = (num & 0xff);
    } else {
        rb_raise(rb_eRangeError, "int %d out of range", num);
    }

    rb_str_buf_cat(ser->stream, tmp, tmp_len);
}

void ser_write_uint16(AMF_SERIALIZER *ser, long num) {
    if(num > 0xffff) rb_raise(rb_eRangeError, "int %ld out of range", num);
    char tmp[2] = {(num >> 8) & 0xff, num & 0xff};
    rb_str_buf_cat(ser->stream, tmp, 2);
}

void ser_write_uint32(AMF_SERIALIZER *ser, long num) {
    if(num > 0xffffffff) rb_raise(rb_eRangeError, "int %ld out of range", num);
	char tmp[4] = {(num >> 24) & 0xff, (num >> 16) & 0xff, (num >> 8) & 0xff, num & 0xff};
	rb_str_buf_cat(ser->stream, tmp, 4);
}

void ser_write_double(AMF_SERIALIZER *ser, double num) {
	union aligned {
		double dval;
		char cval[8];
	} d;
	const char *number = d.cval;
	d.dval = num;

#ifdef WORDS_BIGENDIAN
    rb_str_buf_cat(ser->stream, number, 8);
#else
    char netnum[8] = {number[7],number[6],number[5],number[4],number[3],number[2],number[1],number[0]};
    rb_str_buf_cat(ser->stream, netnum, 8);
#endif
}

void ser_get_string(VALUE obj, VALUE encode, char** str, long* len) {
    int type = TYPE(obj);
    if(type == T_STRING) {
#ifdef HAVE_RB_STR_ENCODE
        if(encode == Qtrue) {
            rb_encoding *enc = rb_enc_get(obj);
            if (enc != rb_ascii8bit_encoding()) {
                rb_encoding *utf8 = rb_utf8_encoding();
                if (enc != utf8) obj = rb_str_encode(obj, rb_enc_from_encoding(utf8), 0, Qnil);
            }
        }
#endif
        *str = RSTRING_PTR(obj);
        *len = RSTRING_LEN(obj);
    } else if(type == T_SYMBOL) {
        *str = (char*)rb_id2name(SYM2ID(obj));
        *len = strlen(*str);
    } else if(obj == Qnil) {
        *len = 0;
    } else {
        rb_raise(rb_eArgError, "Invalid type in ser_get_string: %d", type);
    }
}

static VALUE ser_stream(VALUE self) {
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);
    return ser->stream;
}

/*
 * call-seq:
 *   ser.version => 0
 *
 * Returns the serializer version number, so that a custom encode_amf method
 * knows which version to encode for
 */
static VALUE ser0_version(VALUE self) {
    return INT2FIX(0);
}

/*
 * call-seq:
 *   ser.write_array(ary) => ser
 *
 * Write the given array in AMF0 notation
 */
static VALUE ser0_write_array(VALUE self, VALUE ary) {
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);

    // Cache it
    VALUE obj_id = rb_obj_id(ary);
    st_add_direct(ser->obj_cache, obj_id, LONG2FIX(ser->obj_index));
    ser->obj_index++;

    // Write it out
    long i, len = RARRAY_LEN(ary);
    ser_write_byte(ser, AMF0_STRICT_ARRAY_MARKER);
    ser_write_uint32(ser, len);
    for(i = 0; i < len; i++) {
        ser0_serialize(self, RARRAY_PTR(ary)[i]);
    }

    return self;
}

/*
 * Supports writing strings and symbols. For hash keys, strings all have 16 bit
 * lengths, so writing a type marker is unnecessary. In that case the third
 * parameter should be set to Qfalse instead of Qtrue.
 */
static void ser0_write_string(AMF_SERIALIZER *ser, VALUE obj, VALUE write_marker) {
    // Extract char array and length from object
    char* str;
    long len;
    ser_get_string(obj, Qtrue, &str, &len);

    // Write string
    if(len > 0xffff) {
        if(write_marker == Qtrue) ser_write_byte(ser, AMF0_LONG_STRING_MARKER);
        ser_write_uint32(ser, len);
    } else {
        if(write_marker == Qtrue) ser_write_byte(ser, AMF0_STRING_MARKER);
        ser_write_uint16(ser, len);
    }
    rb_str_buf_cat(ser->stream, str, len);
}

/*
 * Hash iterator for object properties that writes the key and then serializes
 * the value
 */
static int ser0_hash_iter(VALUE key, VALUE val, ITER_ARGS *args) {
    AMF_SERIALIZER *ser;
    Data_Get_Struct(args->ser, AMF_SERIALIZER, ser);

    // Write key and value
    ser0_write_string(ser, key, Qfalse); // Technically incorrect if key length is longer than a 16 bit string, but if you run into that you're screwed anyways
    ser0_serialize(args->ser, val);

    return ST_CONTINUE;
}

/*
 * Used for both hashes and objects. Takes the object and the props hash or Qnil,
 * which forces a call to the class mapper for props for serialization. Prop
 * sorting must be enabled by an explicit call to extconf.rb, so the tests will
 * not pass typically on Ruby 1.8.
 */
static VALUE ser0_write_object0(VALUE self, VALUE obj, VALUE props) {
    static VALUE class_mapper = 0;
    if(class_mapper == 0) class_mapper = rb_const_get(mRocketAMF, rb_intern("ClassMapper"));
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);

    // Cache it
    VALUE obj_id = rb_obj_id(obj);
    st_add_direct(ser->obj_cache, obj_id, LONG2FIX(ser->obj_index));
    ser->obj_index++;

    // Make a request for props hash unless we already have it
    if(props == Qnil) {
        props = rb_funcall(class_mapper, id_props_for_serialization, 1, obj);
    }

    // Write header
    VALUE class_name = rb_funcall(class_mapper, id_get_as_class_name, 1, obj);
    if(class_name != Qnil) {
        ser_write_byte(ser, AMF0_TYPED_OBJECT_MARKER);
        ser0_write_string(ser, class_name, Qfalse);
    } else if(TYPE(obj) == T_HASH) {
        VALUE size = rb_funcall(obj, id_size, 0);
        ser_write_byte(ser, AMF0_HASH_MARKER);
        ser_write_uint32(ser, FIX2LONG(size));
    } else {
        ser_write_byte(ser, AMF0_OBJECT_MARKER);
    }

    // Write out data
    ITER_ARGS args;
    args.ser = self;
#ifdef SORT_PROPS
    // Sort is required prior to Ruby 1.9 to pass all the tests, as Ruby 1.8 hashes don't store insert order
    VALUE sorted_props = rb_funcall(props, rb_intern("sort"), 0);
    long i, len = RARRAY_LEN(sorted_props);
    for(i = 0; i < len; i++) {
        VALUE pair = RARRAY_PTR(sorted_props)[i];
        ser0_hash_iter(RARRAY_PTR(pair)[0], RARRAY_PTR(pair)[1], &args);
    }
#else
    rb_hash_foreach(props, ser0_hash_iter, (st_data_t)&args);
#endif

    ser_write_uint16(ser, 0);
    ser_write_byte(ser, AMF0_OBJECT_END_MARKER);

    return self;
}

/*
 * call-seq:
 *   ser.write_object(obj, props=nil) => ser
 *   ser.write_hash(obj) => ser
 *
 * Write the given object or hash using AMF0 notation. If given a props hash,
 * uses that instead of using the class mapper to calculate it.
 */
static VALUE ser0_write_object(int argc, VALUE *argv, VALUE self) {
    // Check args
    VALUE obj;
    VALUE props = Qnil;
    rb_scan_args(argc, argv, "11", &obj, &props);

    // Call to internal write_object
    return ser0_write_object0(self, obj, props);
}

static VALUE ser0_write_time(VALUE self, VALUE time) {
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);

    ser_write_byte(ser, AMF0_DATE_MARKER);

    // Write time
    time = rb_obj_dup(time);
    rb_funcall(time, id_utc, 0);
    long tmp_num = NUM2DBL(rb_funcall(time, id_to_f, 0)) * 1000;
    ser_write_double(ser, (double)tmp_num);
    ser_write_uint16(ser, 0); // Time zone
}

static VALUE ser0_write_date(VALUE self, VALUE date) {
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);

    ser_write_byte(ser, AMF0_DATE_MARKER);

    // Write time
    double tmp_num = rb_str_to_dbl(rb_funcall(date, rb_intern("strftime"), 1, rb_str_new2("%Q")), Qfalse);
    ser_write_double(ser, tmp_num);
    ser_write_uint16(ser, 0); // Time zone
}

/*
 * call-seq:
 *   ser.serialize(obj) =>str
 *
 * Serializes the object to a string and returns that string
 */
VALUE ser0_serialize(VALUE self, VALUE obj) {
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);

    if(ser->depth == 0) {
        // Initialize caches
        ser->obj_cache = st_init_numtable();
        ser->obj_index = 0;
    }
    ser->depth++;

    int type = TYPE(obj);
    VALUE klass = Qnil;
    if(type == T_OBJECT || type == T_DATA) {
        klass = CLASS_OF(obj);
    }

    VALUE obj_id = rb_obj_id(obj);
    VALUE obj_index;
    if(st_lookup(ser->obj_cache, obj_id, &obj_index)) {
        ser_write_byte(ser, AMF0_REFERENCE_MARKER);
        ser_write_uint16(ser, FIX2LONG(obj_index));
    } else if(rb_respond_to(obj, id_encode_amf)) {
        rb_funcall(obj, id_encode_amf, 1, self);
    } else if(type == T_STRING || type == T_SYMBOL) {
        ser0_write_string(ser, obj, Qtrue);
    } else if(type == T_FIXNUM) {
        ser_write_byte(ser, AMF0_NUMBER_MARKER);
        ser_write_double(ser, (double)FIX2LONG(obj));
    } else if(type == T_FLOAT) {
        ser_write_byte(ser, AMF0_NUMBER_MARKER);
        ser_write_double(ser, RFLOAT_VALUE(obj));
    } else if(type == T_NIL) {
        ser_write_byte(ser, AMF0_NULL_MARKER);
    } else if(type == T_TRUE || type == T_FALSE) {
        ser_write_byte(ser, AMF0_BOOLEAN_MARKER);
        ser_write_byte(ser, type == T_TRUE ? 1 : 0);
    } else if(type == T_ARRAY) {
        ser0_write_array(self, obj);
    } else if(klass == rb_cTime) {
        ser0_write_time(self, obj);
    } else if(klass == cDate || klass == cDateTime) {
        ser0_write_date(self, obj);
    } else if(type == T_BIGNUM) {
        ser_write_byte(ser, AMF0_NUMBER_MARKER);
        ser_write_double(ser, rb_big2dbl(obj));
    } else if(type == T_HASH || type == T_OBJECT) {
        ser0_write_object0(self, obj, Qnil);
    }

    ser->depth--;

    if(ser->depth == 0) {
        // Clean up
        xfree(ser->obj_cache);
        ser->obj_cache = NULL;
    }
    return ser->stream;
}

/*
 * call-seq:
 *   ser.version => 3
 *
 * Returns the serializer version number, so that a custom encode_amf method
 * knows which version to encode for
 */
static VALUE ser3_version(VALUE self) {
    return INT2FIX(3);
}

/*
 * Writes an AMF3 style string. Accepts strings, symbols, and nil, and handles
 * all the necessary encoding and caching.
 */
static void ser3_write_utf8vr(AMF_SERIALIZER *ser, VALUE obj, VALUE encode, VALUE cache) {
    // Extract char array and length from object
    char* str;
    long len;
    ser_get_string(obj, encode, &str, &len);

    // Write string
    VALUE str_index;
    if(len == 0) {
        ser_write_byte(ser, AMF3_EMPTY_STRING);
    } else if(st_lookup(ser->str_cache, (st_data_t)str, &str_index)) {
        ser_write_int(ser, FIX2INT(str_index) << 1);
    } else {
        if(cache == Qtrue) st_add_direct(ser->str_cache, (st_data_t)strdup(str), LONG2FIX(ser->str_index));
        ser->str_index++;

        ser_write_int(ser, ((int)len) << 1 | 1);
        rb_str_buf_cat(ser->stream, str, len);
    }
}

/*
 * call-seq:
 *   ser.write_array(ary) => ser
 *
 * Writes the given array using AMF3 notation
 */
static VALUE ser3_write_array(VALUE self, VALUE ary) {
    static VALUE class_mapper = 0;
    if(class_mapper == 0) class_mapper = rb_const_get(mRocketAMF, rb_intern("ClassMapper"));
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);

    // Is it an array collection?
    VALUE is_ac = Qfalse;
    if(rb_respond_to(ary, id_is_array_collection)) {
        is_ac = rb_funcall(ary, id_is_array_collection, 0);
    } else {
        is_ac = rb_funcall(class_mapper, id_use_array_collection, 0);
    }

    // Write type marker
    ser_write_byte(ser, is_ac ? AMF3_OBJECT_MARKER : AMF3_ARRAY_MARKER);

    // Write object ref, or cache it
    VALUE obj_id = rb_obj_id(ary);
    VALUE obj_index;
    if(st_lookup(ser->obj_cache, obj_id, &obj_index)) {
        ser_write_int(ser, FIX2INT(obj_index) << 1);
        return self;
    } else {
        st_add_direct(ser->obj_cache, obj_id, LONG2FIX(ser->obj_index));
        ser->obj_index++;
    }

    // Write out traits and array marker if it's an array collection
    if(is_ac) {
        VALUE trait_index;
        char array_collection_name[34] = "flex.messaging.io.ArrayCollection";
        if(st_lookup(ser->trait_cache, (st_data_t)array_collection_name, &trait_index)) {
            ser_write_int(ser, FIX2INT(trait_index) << 2 | 0x01);
        } else {
            st_add_direct(ser->trait_cache, (st_data_t)strdup(array_collection_name), LONG2FIX(ser->trait_index));
            ser->trait_index++;
            ser_write_byte(ser, 0x07); // Trait header
            ser_write_byte(ser, 0x43); // utf8vr header
            rb_str_buf_cat(ser->stream, array_collection_name, 33); // Class name
        }
        ser_write_byte(ser, AMF3_ARRAY_MARKER);
    }

    // Write header
    int header = ((int)RARRAY_LEN(ary)) << 1 | 1;
    ser_write_int(ser, header);
    ser_write_byte(ser, AMF3_CLOSE_DYNAMIC_ARRAY);

    // Write contents
    long i, len = RARRAY_LEN(ary);
    for(i = 0; i < len; i++) {
        ser3_serialize(self, RARRAY_PTR(ary)[i]);
    }

    return self;
}

/*
 * AMF3 property hash write iterator. Checks the args->extra hash, if given,
 * and skips properties that are keys in that hash.
 */
static int ser3_hash_iter(VALUE key, VALUE val, ITER_ARGS *args) {
    AMF_SERIALIZER *ser;
    Data_Get_Struct(args->ser, AMF_SERIALIZER, ser);

    if(args->extra == Qnil || rb_funcall(args->extra, id_haskey, 1, key) == Qfalse) {
        // Write key and value
        ser3_write_utf8vr(ser, key, Qtrue, Qtrue);
        ser3_serialize(args->ser, val);
    }
    return ST_CONTINUE;
}

/*
 * Used for both hashes and objects. Takes the object and the props hash or Qnil,
 * which forces a call to the class mapper for props for serialization. Prop
 * sorting must be enabled by an explicit call to extconf.rb, so the tests will
 * not pass typically on Ruby 1.8. If you need to have specific traits, you can
 * also pass that in, or pass Qnil to use the default traits - dynamic with no
 * defined members.
 */
static VALUE ser3_write_object0(VALUE self, VALUE obj, VALUE props, VALUE traits) {
    static VALUE class_mapper = 0;
    if(class_mapper == 0) class_mapper = rb_const_get(mRocketAMF, rb_intern("ClassMapper"));
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);
    long i;

    // Write type marker
    ser_write_byte(ser, AMF3_OBJECT_MARKER);

    // Write object ref, or cache it
    VALUE obj_id = rb_obj_id(obj);
    VALUE obj_index;
    if(st_lookup(ser->obj_cache, obj_id, &obj_index)) {
        ser_write_int(ser, FIX2INT(obj_index) << 1);
        return self;
    } else {
        st_add_direct(ser->obj_cache, obj_id, LONG2FIX(ser->obj_index));
        ser->obj_index++;
    }

    // Extract traits data, or use defaults
    VALUE class_name = Qnil;
    VALUE members = Qnil;
    long members_len = 0;
    VALUE dynamic = Qtrue;
    VALUE externalizable = Qfalse;
    if(traits == Qnil) {
        class_name = rb_funcall(class_mapper, id_get_as_class_name, 1, obj);
    } else {
        class_name = rb_hash_aref(traits, sym_class_name);
        members = rb_hash_aref(traits, sym_members);
        if(members != Qnil) members_len = RARRAY_LEN(members);
        dynamic = rb_hash_aref(traits, sym_dynamic);
        externalizable = rb_hash_aref(traits, sym_externalizable);
    }

    // Handle trait caching
    int did_ref = 0;
    VALUE trait_index;
    if(class_name != Qnil) {
        if(st_lookup(ser->trait_cache, (st_data_t)RSTRING_PTR(class_name), &trait_index)) {
            ser_write_int(ser, FIX2INT(trait_index) << 2 | 0x01);
            did_ref = 1;
        } else {
            st_add_direct(ser->trait_cache, (st_data_t)strdup(RSTRING_PTR(class_name)), LONG2FIX(ser->trait_index));
            ser->trait_index++;
        }
    }

    // Write traits outs if didn't write reference
    if(!did_ref) {
        // Write out trait header
        int header = 0x03;
        if(dynamic == Qtrue) header |= 0x02 << 2;
        if(externalizable == Qtrue) header |= 0x01 << 2;
        header |= ((int)members_len) << 4;
        ser_write_int(ser, header);

        // Write class name
        ser3_write_utf8vr(ser, class_name, Qtrue, Qtrue);

        // Write out members
        for(i = 0; i < members_len; i++) {
            ser3_write_utf8vr(ser, RARRAY_PTR(members)[i], Qtrue, Qtrue);
        }
    }

    // Raise exception if marked externalizable
    if(externalizable == Qtrue) {
        rb_funcall(obj, rb_intern("write_external"), 1, self);
        return self;
    }

    // Make a request for props hash unless we already have it
    if(props == Qnil) {
        props = rb_funcall(class_mapper, id_props_for_serialization, 1, obj);
    }

    // Write sealed members
    VALUE skipped_members = members_len ? rb_hash_new() : Qnil;
    for(i = 0; i < members_len; i++) {
        ser3_serialize(self, rb_hash_aref(props, RARRAY_PTR(members)[i]));
        rb_hash_aset(skipped_members, RARRAY_PTR(members)[i], Qtrue);
    }

    // Write dynamic properties
    if(dynamic == Qtrue) {
        ITER_ARGS args;
        args.ser = self;
        args.extra = skipped_members;
#ifdef SORT_PROPS
        // Sort is required prior to Ruby 1.9 to pass all the tests, as Ruby 1.8 hashes don't store insert order
        VALUE sorted_props = rb_funcall(props, rb_intern("sort"), 0);
        for(i = 0; i < RARRAY_LEN(sorted_props); i++) {
            VALUE pair = RARRAY_PTR(sorted_props)[i];
            ser3_hash_iter(RARRAY_PTR(pair)[0], RARRAY_PTR(pair)[1], &args);
        }
#else
        rb_hash_foreach(props, ser3_hash_iter, (st_data_t)&args);
#endif

        ser_write_byte(ser, AMF3_CLOSE_DYNAMIC_OBJECT);
    }

    return self;
}

/*
 * call-seq:
 *   ser.write_object(obj, props=nil, traits=nil) => ser
 *
 * Write the given object or hash using AMF3 notation. If given a props hash,
 * uses that instead of using the class mapper to calculate it. If given a traits
 * hash, uses that instead of the default dynamic traits with the mapped class
 * name.
 */
static VALUE ser3_write_object(int argc, VALUE *argv, VALUE self) {
    // Check args
    VALUE obj;
    VALUE props = Qnil;
    VALUE traits = Qnil;
    rb_scan_args(argc, argv, "12", &obj, &props, &traits);

    // Call to internal write_object
    return ser3_write_object0(self, obj, props, traits);
}

static VALUE ser3_write_time(VALUE self, VALUE time) {
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);

    ser_write_byte(ser, AMF3_DATE_MARKER);

    // Write object ref, or cache it
    VALUE obj_id = rb_obj_id(time);
    VALUE obj_index;
    if(st_lookup(ser->obj_cache, obj_id, &obj_index)) {
        ser_write_int(ser, FIX2INT(obj_index) << 1);
        return;
    } else {
        st_add_direct(ser->obj_cache, obj_id, LONG2FIX(ser->obj_index));
        ser->obj_index++;
    }

    // Write time
    ser_write_byte(ser, AMF3_NULL_MARKER); // Ref header
    time = rb_obj_dup(time);
    rb_funcall(time, id_utc, 0);
    long tmp_num = NUM2DBL(rb_funcall(time, id_to_f, 0)) * 1000;
    ser_write_double(ser, (double)tmp_num);
}

static VALUE ser3_write_date(VALUE self, VALUE date) {
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);

    ser_write_byte(ser, AMF3_DATE_MARKER);

    // Write object ref, or cache it
    VALUE obj_id = rb_obj_id(date);
    VALUE obj_index;
    if(st_lookup(ser->obj_cache, obj_id, &obj_index)) {
        ser_write_int(ser, FIX2INT(obj_index) << 1);
        return;
    } else {
        st_add_direct(ser->obj_cache, obj_id, LONG2FIX(ser->obj_index));
        ser->obj_index++;
    }

    // Write time
    ser_write_byte(ser, AMF3_NULL_MARKER); // Ref header
    double tmp_num = rb_str_to_dbl(rb_funcall(date, rb_intern("strftime"), 1, rb_str_new2("%Q")), Qfalse);
    ser_write_double(ser, tmp_num);
}

static VALUE ser3_write_byte_array(VALUE self, VALUE ba) {
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);

    ser_write_byte(ser, AMF3_BYTE_ARRAY_MARKER);

    // Write object ref, or cache it
    VALUE obj_id = rb_obj_id(ba);
    VALUE obj_index;
    if(st_lookup(ser->obj_cache, obj_id, &obj_index)) {
        ser_write_int(ser, FIX2INT(obj_index) << 1);
        return;
    } else {
        st_add_direct(ser->obj_cache, obj_id, LONG2FIX(ser->obj_index));
        ser->obj_index++;
    }

    // Write byte array
    ser3_write_utf8vr(ser, rb_funcall(ba, rb_intern("string"), 0), Qfalse, Qfalse);
}

VALUE ser3_serialize(VALUE self, VALUE obj) {
    AMF_SERIALIZER *ser;
    Data_Get_Struct(self, AMF_SERIALIZER, ser);

    if(ser->depth == 0) {
        // Initialize caches
        ser->str_cache = st_init_strtable();
        ser->str_index = 0;
        ser->trait_cache = st_init_strtable();
        ser->trait_index = 0;
        ser->obj_cache = st_init_numtable();
        ser->obj_index = 0;
    }
    ser->depth++;

    int type = TYPE(obj);
    VALUE klass = Qnil;
    if(type == T_OBJECT || type == T_DATA || type == T_ARRAY) {
        klass = CLASS_OF(obj);
    }

    if(rb_respond_to(obj, id_encode_amf)) {
        rb_funcall(obj, id_encode_amf, 1, self);
    } else if(type == T_STRING || type == T_SYMBOL) {
        ser_write_byte(ser, AMF3_STRING_MARKER);
        ser3_write_utf8vr(ser, obj, Qtrue, Qtrue);
    } else if(type == T_FIXNUM) {
        long tmp_num = FIX2LONG(obj);
        if(tmp_num < MIN_INTEGER || tmp_num > MAX_INTEGER) {
            // Outside range so convert to double and serialize as float
            ser_write_byte(ser, AMF3_DOUBLE_MARKER);
            ser_write_double(ser, (double)tmp_num);
        } else {
            // Inside valid integer range
            ser_write_byte(ser, AMF3_INTEGER_MARKER);
            ser_write_int(ser, (int)tmp_num);
        }
    } else if(type == T_FLOAT) {
        ser_write_byte(ser, AMF3_DOUBLE_MARKER);
        ser_write_double(ser, RFLOAT_VALUE(obj));
    } else if(type == T_NIL) {
        ser_write_byte(ser, AMF3_NULL_MARKER);
    } else if(type == T_TRUE) {
        ser_write_byte(ser, AMF3_TRUE_MARKER);
    } else if(type == T_FALSE) {
        ser_write_byte(ser, AMF3_FALSE_MARKER);
    } else if(type == T_ARRAY) {
        ser3_write_array(self, obj);
    } else if(type == T_HASH) {
        ser3_write_object0(self, obj, Qnil, Qnil);
    } else if(klass == rb_cTime) {
        ser3_write_time(self, obj);
    } else if(klass == cDate || klass == cDateTime) {
        ser3_write_date(self, obj);
    } else if(klass == cStringIO) {
        ser3_write_byte_array(self, obj);
    } else if(type == T_BIGNUM) {
        ser_write_byte(ser, AMF3_DOUBLE_MARKER);
        ser_write_double(ser, rb_big2dbl(obj));
    } else if(type == T_OBJECT) {
        ser3_write_object0(self, obj, Qnil, Qnil);
    }

    ser->depth--;

    if(ser->depth == 0) {
        // Clean up
        xfree(ser->str_cache);
        ser->str_cache = NULL;
        xfree(ser->trait_cache);
        ser->trait_cache = NULL;
        xfree(ser->obj_cache);
        ser->obj_cache = NULL;
    }
    return ser->stream;
}

void Init_rocket_amf_serializer() {
    // Define Serializer
    cSerializer = rb_define_class_under(mRocketAMFExt, "Serializer", rb_cObject);
    rb_define_alloc_func(cSerializer, ser_alloc);
    rb_define_method(cSerializer, "version", ser0_version, 0);
    rb_define_method(cSerializer, "stream", ser_stream, 0);
    rb_define_method(cSerializer, "serialize", ser0_serialize, 1);
    rb_define_method(cSerializer, "write_array", ser0_write_array, 1);
    rb_define_method(cSerializer, "write_hash", ser0_write_object, -1);
    rb_define_method(cSerializer, "write_object", ser0_write_object, -1);

    // Define AMF3Serializer
    cAMF3Serializer = rb_define_class_under(mRocketAMFExt, "AMF3Serializer", rb_cObject);
    rb_define_alloc_func(cAMF3Serializer, ser_alloc);
    rb_define_method(cAMF3Serializer, "version", ser3_version, 0);
    rb_define_method(cAMF3Serializer, "stream", ser_stream, 0);
    rb_define_method(cAMF3Serializer, "serialize", ser3_serialize, 1);
    rb_define_method(cAMF3Serializer, "write_array", ser3_write_array, 1);
    rb_define_method(cAMF3Serializer, "write_object", ser3_write_object, -1);

    // Get refs to commonly used symbols and ids
    id_size = rb_intern("size");
    id_haskey = rb_intern("has_key?");
    id_encode_amf = rb_intern("encode_amf");
    id_is_array_collection = rb_intern("is_array_collection?");
    id_use_array_collection = rb_intern("use_array_collection");
    id_get_as_class_name = rb_intern("get_as_class_name");
    id_props_for_serialization = rb_intern("props_for_serialization");
    id_utc = rb_intern("utc");
    id_to_f = rb_intern("to_f");
}