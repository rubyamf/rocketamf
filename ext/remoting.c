#include "deserializer.h"
#include "serializer.h"
#include "constants.h"

extern VALUE mRocketAMF;
extern VALUE mRocketAMFExt;
extern VALUE cDeserializer;
extern VALUE cSerializer;
VALUE cRocketAMFHeader;
VALUE cRocketAMFMessage;
VALUE cRocketAMFAbstractMessage;
ID id_amf_version;
ID id_headers;
ID id_messages;
ID id_data;

static VALUE env_populate_from_stream(int argc, VALUE *argv, VALUE self) {
    static VALUE cClassMapper = 0;
    if(cClassMapper == 0) cClassMapper = rb_const_get(mRocketAMF, rb_intern("ClassMapper"));

    // Parse args
    VALUE src;
    VALUE class_mapper;
    rb_scan_args(argc, argv, "11", &src, &class_mapper);
    if(class_mapper == Qnil) class_mapper = rb_class_new_instance(0, NULL, cClassMapper);

    // Create AMF0 deserializer
    VALUE args[3];
    args[0] = class_mapper;
    VALUE des_rb = rb_class_new_instance(1, args, cDeserializer);
    AMF_DESERIALIZER *des;
    Data_Get_Struct(des_rb, AMF_DESERIALIZER, des);
    des_set_src(des, src);

    // Read amf version
    int amf_ver = des_read_uint16(des);

    // Read headers
    VALUE headers = rb_hash_new();
    int header_cnt = des_read_uint16(des);
    int i;
    for(i = 0; i < header_cnt; i++) {
        VALUE name = des_read_string(des, des_read_uint16(des));
        VALUE must_understand = des_read_byte(des) != 0 ? Qtrue : Qfalse;
        des_read_uint32(des); // Length is ignored
        VALUE data = des_deserialize(des_rb, INT2FIX(0), Qnil);

        args[0] = name;
        args[1] = must_understand;
        args[2] = data;
        rb_hash_aset(headers, name, rb_class_new_instance(3, args, cRocketAMFHeader));
    }

    // Read messages
    VALUE messages = rb_ary_new();
    int message_cnt = des_read_uint16(des);
    for(i = 0; i < message_cnt; i++) {
        VALUE target_uri = des_read_string(des, des_read_uint16(des));
        VALUE response_uri = des_read_string(des, des_read_uint16(des));
        des_read_uint32(des); // Length is ignored
        VALUE data = des_deserialize(des_rb, INT2FIX(0), Qnil);

        // If they're using the flex remoting APIs, remove array wrapper
        if(TYPE(data) == T_ARRAY && RARRAY_LEN(data) == 1 && rb_obj_is_kind_of(RARRAY_PTR(data)[0], cRocketAMFAbstractMessage) == Qtrue) {
            data = RARRAY_PTR(data)[0];
        }

        args[0] = target_uri;
        args[1] = response_uri;
        args[2] = data;
        rb_ary_push(messages, rb_class_new_instance(3, args, cRocketAMFMessage));
    }

    // Populate remoting object
    rb_ivar_set(self, id_amf_version, INT2FIX(amf_ver));
    rb_ivar_set(self, id_headers, headers);
    rb_ivar_set(self, id_messages, messages);

    return self;
}

static VALUE env_serialize(int argc, VALUE *argv, VALUE self) {
    static VALUE cClassMapper = 0;
    if(cClassMapper == 0) cClassMapper = rb_const_get(mRocketAMF, rb_intern("ClassMapper"));

    // Parse args
    VALUE class_mapper;
    rb_scan_args(argc, argv, "01", &class_mapper);
    if(class_mapper == Qnil) class_mapper = rb_class_new_instance(0, NULL, cClassMapper);

    // Get instance variables
    long amf_ver = FIX2LONG(rb_ivar_get(self, id_amf_version));
    VALUE headers = rb_funcall(rb_ivar_get(self, id_headers), rb_intern("values"), 0); // Get array of header values
    VALUE messages = rb_ivar_get(self, id_messages);

    // Create AMF0 serializer
    VALUE args[1] = {class_mapper};
    VALUE ser_rb = rb_class_new_instance(1, args, cSerializer);
    AMF_SERIALIZER *ser;
    Data_Get_Struct(ser_rb, AMF_SERIALIZER, ser);

    // Write version
    ser_write_uint16(ser, amf_ver);

    // Write headers
    long header_cnt = RARRAY_LEN(headers);
    ser_write_uint16(ser, header_cnt);
    int i;
    char *str;
    long str_len;
    for(i = 0; i < header_cnt; i++) {
        VALUE header = RARRAY_PTR(headers)[i];

        // Write header name
        ser_get_string(rb_funcall(header, rb_intern("name"), 0), Qtrue, &str, &str_len);
        ser_write_uint16(ser, str_len);
        rb_str_buf_cat(ser->stream, str, str_len);

        // Write understand flag
        ser_write_byte(ser, rb_funcall(header, rb_intern("must_understand"), 0) == Qtrue ? 1 : 0);

        // Serialize data
        ser_write_uint32(ser, -1); // length of data - -1 if you don't know
        ser_serialize(ser_rb, INT2FIX(0), rb_funcall(header, id_data, 0));
    }

    // Write messages
    long message_cnt = RARRAY_LEN(messages);
    ser_write_uint16(ser, message_cnt);
    for(i = 0; i < message_cnt; i++) {
        VALUE message = RARRAY_PTR(messages)[i];

        // Write target_uri
        ser_get_string(rb_funcall(message, rb_intern("target_uri"), 0), Qtrue, &str, &str_len);
        ser_write_uint16(ser, str_len);
        rb_str_buf_cat(ser->stream, str, str_len);

        // Write response_uri
        ser_get_string(rb_funcall(message, rb_intern("response_uri"), 0), Qtrue, &str, &str_len);
        ser_write_uint16(ser, str_len);
        rb_str_buf_cat(ser->stream, str, str_len);

        // Serialize data
        ser_write_uint32(ser, -1); // length of data - -1 if you don't know
        if(amf_ver == 3) {
            ser_write_byte(ser, AMF0_AMF3_MARKER);
            ser_serialize(ser_rb, INT2FIX(3), rb_funcall(message, id_data, 0));
        } else {
            ser_serialize(ser_rb, INT2FIX(0), rb_funcall(message, id_data, 0));
        }
    }

    return ser->stream;
}


void Init_rocket_amf_remoting() {
    VALUE mEnvelope = rb_define_module_under(mRocketAMFExt, "Envelope");
    rb_define_method(mEnvelope, "populate_from_stream", env_populate_from_stream, -1);
    rb_define_method(mEnvelope, "serialize", env_serialize, -1);

    // Get refs to commonly used symbols and ids
    id_amf_version = rb_intern("@amf_version");
    id_headers = rb_intern("@headers");
    id_messages = rb_intern("@messages");
    id_data = rb_intern("data");
    cRocketAMFHeader = rb_const_get(mRocketAMF, rb_intern("Header"));
    cRocketAMFMessage = rb_const_get(mRocketAMF, rb_intern("Message"));
    cRocketAMFAbstractMessage = rb_const_get(rb_const_get(mRocketAMF, rb_intern("Values")), rb_intern("AbstractMessage"));
}