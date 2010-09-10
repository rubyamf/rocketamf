#include <ruby.h>

VALUE mRocketAMF;
VALUE mRocketAMFExt;
VALUE cStringIO;
VALUE sym_class_name;
VALUE sym_members;
VALUE sym_externalizable;
VALUE sym_dynamic;

void Init_rocket_amf_deserializer();
void Init_rocket_amf_serializer();
void Init_rocket_amf_fast_class_mapping();

void Init_rocketamf_ext() {
    mRocketAMF = rb_define_module("RocketAMF");
    mRocketAMFExt = rb_define_module_under(mRocketAMF, "Ext");

    // Set up classes
    Init_rocket_amf_deserializer();
    Init_rocket_amf_serializer();
    Init_rocket_amf_fast_class_mapping();

    // Get refs to commonly used symbols and ids
    cStringIO = rb_const_get(rb_cObject, rb_intern("StringIO"));
    sym_class_name = ID2SYM(rb_intern("class_name"));
    sym_members = ID2SYM(rb_intern("members"));
    sym_externalizable = ID2SYM(rb_intern("externalizable"));
    sym_dynamic = ID2SYM(rb_intern("dynamic"));
}