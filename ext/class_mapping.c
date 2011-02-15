#include <ruby.h>
#include <ruby/st.h>
#include "utility.h"

extern VALUE mRocketAMF;
extern VALUE mRocketAMFExt;
VALUE cFastMappingSet;
VALUE cTypedHash;
ID id_hashset;

typedef struct {
    VALUE mapset;
    st_table* setter_cache;
    st_table* prop_cache;
} CLASS_MAPPING;

typedef struct {
    st_table* as_mappings;
    st_table* rb_mappings;
} MAPSET;

/*
 * Mark the as_mappings and rb_mappings hashes
 */
static void mapset_mark(MAPSET *set) {
    if(!set) return;
    rb_mark_tbl(set->as_mappings);
    rb_mark_tbl(set->rb_mappings);
}

/*
 * Free the mapping tables and struct
 */
static void mapset_free(MAPSET *set) {
    st_free_table(set->as_mappings);
    st_free_table(set->rb_mappings);
    xfree(set);
}

/*
 * Allocate mapset and populate mappings with built-in mappings
 */
static VALUE mapset_alloc(VALUE klass) {
    MAPSET *set = ALLOC(MAPSET);
    memset(set, 0, sizeof(MAPSET));
    VALUE self = Data_Wrap_Struct(klass, mapset_mark, mapset_free, set);

    // Initialize internal data
    set->as_mappings = st_init_strtable();
    set->rb_mappings = st_init_strtable();

    // Populate with built-in mappings
    st_add_direct(set->as_mappings, (st_data_t)"flex.messaging.messages.AbstractMessage", rb_str_new2("RocketAMF::Values::AbstractMessage"));
    st_add_direct(set->as_mappings, (st_data_t)"flex.messaging.messages.RemotingMessage", rb_str_new2("RocketAMF::Values::RemotingMessage"));
    st_add_direct(set->as_mappings, (st_data_t)"flex.messaging.messages.AsyncMessage", rb_str_new2("RocketAMF::Values::AsyncMessage"));
    st_add_direct(set->as_mappings, (st_data_t)"flex.messaging.messages.CommandMessage", rb_str_new2("RocketAMF::Values::CommandMessage"));
    st_add_direct(set->as_mappings, (st_data_t)"flex.messaging.messages.AcknowledgeMessage", rb_str_new2("RocketAMF::Values::AcknowledgeMessage"));
    st_add_direct(set->as_mappings, (st_data_t)"flex.messaging.messages.ErrorMessage", rb_str_new2("RocketAMF::Values::ErrorMessage"));

    st_add_direct(set->rb_mappings, (st_data_t)"RocketAMF::Values::AbstractMessage", rb_str_new2("flex.messaging.messages.AbstractMessage"));
    st_add_direct(set->rb_mappings, (st_data_t)"RocketAMF::Values::RemotingMessage", rb_str_new2("flex.messaging.messages.RemotingMessage"));
    st_add_direct(set->rb_mappings, (st_data_t)"RocketAMF::Values::AsyncMessage", rb_str_new2("flex.messaging.messages.AsyncMessage"));
    st_add_direct(set->rb_mappings, (st_data_t)"RocketAMF::Values::CommandMessage", rb_str_new2("flex.messaging.messages.CommandMessage"));
    st_add_direct(set->rb_mappings, (st_data_t)"RocketAMF::Values::AcknowledgeMessage", rb_str_new2("flex.messaging.messages.AcknowledgeMessage"));
    st_add_direct(set->rb_mappings, (st_data_t)"RocketAMF::Values::ErrorMessage", rb_str_new2("flex.messaging.messages.ErrorMessage"));

    return self;
}

/*
 * call-seq:
 *   m.map :as => 'com.example.Date', :ruby => "Example::Date'
 *
 * Map a given AS class to a ruby class. Use fully qualified names for both.
 */
static VALUE mapset_map(VALUE self, VALUE mapping) {
    MAPSET *set;
    Data_Get_Struct(self, MAPSET, set);

    VALUE as_class = rb_hash_aref(mapping, ID2SYM(rb_intern("as")));
    VALUE rb_class = rb_hash_aref(mapping, ID2SYM(rb_intern("ruby")));
    st_insert(set->as_mappings, (st_data_t)strdup(RSTRING_PTR(as_class)), rb_class);
    st_insert(set->rb_mappings, (st_data_t)strdup(RSTRING_PTR(rb_class)), as_class);

    return Qnil;
}

/*
 * Internal method for looking up a given ruby class's AS class name or Qnil if
 * not found
 */
static VALUE mapset_as_lookup(VALUE self, const char* class_name) {
    MAPSET *set;
    Data_Get_Struct(self, MAPSET, set);

    VALUE as_name;
    if(st_lookup(set->rb_mappings, (st_data_t)class_name, &as_name)) {
        return as_name;
    } else {
        return Qnil;
    }
}

/*
 * Internal method for looking up a given AS class names ruby class name mapping
 * or Qnil if not found
 */
static VALUE mapset_rb_lookup(VALUE self, const char* class_name) {
    MAPSET *set;
    Data_Get_Struct(self, MAPSET, set);

    VALUE rb_name;
    if(st_lookup(set->as_mappings, (st_data_t)class_name, &rb_name)) {
        return rb_name;
    } else {
        return Qnil;
    }
}

/*
 * Mark the mapset object and property lookup cache
 */
static void mapping_mark(CLASS_MAPPING *map) {
    if(!map) return;
    rb_gc_mark(map->mapset);
    rb_mark_tbl(map->prop_cache);
}

/*
 * Free prop cache table and struct
 */
static void mapping_free(CLASS_MAPPING *map) {
    st_free_table(map->setter_cache);
    st_free_table(map->prop_cache);
    xfree(map);
}

/*
 * Allocate class mapping struct
 */
static VALUE mapping_alloc(VALUE klass) {
    CLASS_MAPPING *map = ALLOC(CLASS_MAPPING);
    memset(map, 0, sizeof(CLASS_MAPPING));
    VALUE self = Data_Wrap_Struct(klass, mapping_mark, mapping_free, map);
    map->mapset = rb_class_new_instance(0, NULL, cFastMappingSet);
    map->setter_cache = st_init_numtable();
    map->prop_cache = st_init_numtable();
    return self;
}

/*
 * Initialize class mapping object, setting use_class_mapping to false
 */
static VALUE mapping_init(VALUE self) {
    rb_ivar_set(self, rb_intern("@use_array_collection"), Qfalse);
}

/*
 * call-seq:
 *   mapper.define {|m| block } => nil
 *
 * Define class mappings in the block. Block is passed a MappingSet object as
 * the first parameter. See RocketAMF::ClassMapping for details.
 */
static VALUE mapping_define(VALUE self) {
    CLASS_MAPPING *map;
    Data_Get_Struct(self, CLASS_MAPPING, map);

	if (rb_block_given_p()) {
	    rb_yield(map->mapset);
	}

	return Qnil;
}

/*
 * Reset class mappings
 */
static VALUE mapping_reset(VALUE self) {
    CLASS_MAPPING *map;
    Data_Get_Struct(self, CLASS_MAPPING, map);

    map->mapset = rb_class_new_instance(0, NULL, cFastMappingSet);

    return Qnil;
}

/*
 * call-seq:
 *   mapper.get_as_class_name => str
 *
 * Returns the AS class name for the given ruby object. Will also take a string
 * containing the ruby class name.
 */
static VALUE mapping_as_class_name(VALUE self, VALUE obj) {
    CLASS_MAPPING *map;
    Data_Get_Struct(self, CLASS_MAPPING, map);

    int type = TYPE(obj);
    const char* class_name;
    if(type == T_STRING) {
        // Use strings as the class name
        class_name = RSTRING_PTR(obj);
    } else {
        // Look up the class name and use that
        VALUE klass = CLASS_OF(obj);
        class_name = rb_class2name(klass);
        if(klass == cTypedHash) {
            VALUE orig_name = rb_funcall(obj, rb_intern("type"), 0);
            class_name = RSTRING_PTR(orig_name);
        } else if(type == T_HASH) {
            // Don't bother looking up hash mapping, but need to check class name first in case it's a typed hash
            return Qnil;
        }
    }

    return mapset_as_lookup(map->mapset, class_name);
}

/*
 * call_seq:
 *   mapper.get_ruby_obj => obj
 *
 * Instantiates a ruby object using the mapping configuration based on the
 * source AS class name. If there is no mapping defined, it returns a
 * <tt>RocketAMF::Values::TypedHash</tt> with the serialized class name.
 */
static VALUE mapping_get_ruby_obj(VALUE self, VALUE name) {
    CLASS_MAPPING *map;
    Data_Get_Struct(self, CLASS_MAPPING, map);

    VALUE argv[1];
    VALUE ruby_class_name = mapset_rb_lookup(map->mapset, RSTRING_PTR(name));
    if(ruby_class_name == Qnil) {
        argv[0] = name;
        return rb_class_new_instance(1, argv, cTypedHash);
    } else {
        VALUE base_const = rb_mKernel;
        char* endptr;
        char* ptr = RSTRING_PTR(ruby_class_name);
        while(endptr = strstr(ptr,"::")) {
            endptr[0] = '\0'; // NULL terminate to make string ops work
            base_const = rb_const_get(base_const, rb_intern(ptr));
            endptr[0] = ':'; // Restore correct char
            ptr = endptr + 2;
        }
        return rb_class_new_instance(0, NULL, rb_const_get(base_const, rb_intern(ptr)));
    }
}

/*
 * st_table iterator for populating a given object from a property hash
 */
static int mapping_populate_iter(VALUE key, VALUE val, const VALUE args[2]) {
    CLASS_MAPPING *map;
    Data_Get_Struct(args[0], CLASS_MAPPING, map);
    VALUE obj = args[1];

    if(TYPE(obj) == T_HASH) {
        rb_hash_aset(obj, key, val);
        return ST_CONTINUE;
    }

    if(TYPE(key) != T_SYMBOL) rb_raise(rb_eArgError, "Invalid type for property key: %d", TYPE(key));

    // Calculate symbol for setter function
    ID key_id = SYM2ID(key);
    ID setter_id;
    if(!st_lookup(map->setter_cache, key_id, &setter_id)) {
        // Calculate symbol
        const char* key_str = rb_id2name(key_id);
        long len = strlen(key_str);
        char* setter = ALLOC_N(char, len+2);
        memcpy(setter, key_str, len);
        setter[len] = '=';
        setter[len+1] = '\0';
        setter_id = rb_intern(setter);
        xfree(setter);

        // Store it
        st_add_direct(map->setter_cache, key_id, setter_id);
    }

    if(rb_respond_to(obj, setter_id)) {
        rb_funcall(obj, setter_id, 1, val);
    } else if(rb_respond_to(obj, id_hashset)) {
        rb_funcall(obj, id_hashset, 2, key, val);
    }

    return ST_CONTINUE;
}

/*
 * call-seq:
 *   mapper.populate_ruby_obj(obj, props, dynamic_props=nil) => obj
 *
 * Populates the ruby object using the given properties. Property hashes MUST
 * have symbol keys, or it will raise an exception.
 */
static VALUE mapping_populate(int argc, VALUE *argv, VALUE self) {
    // Check args
    VALUE obj, props, dynamic_props;
    rb_scan_args(argc, argv, "21", &obj, &props, &dynamic_props);

    VALUE args[2] = {self, obj};
    st_foreach(RHASH_TBL(props), mapping_populate_iter, (st_data_t)args);
    if(dynamic_props != Qnil) {
        st_foreach(RHASH_TBL(dynamic_props), mapping_populate_iter, (st_data_t)args);
    }

    return obj;
}

/*
 * call-seq:
 *   mapper.props_for_serialization(obj) => hash
 *
 * Extracts all exportable properties from the given ruby object and returns
 * them in a hash. For performance purposes, property detection is only performed
 * once for a given class instance, and then cached for all instances of that
 * class. IF YOU'RE ADDING AND REMOVING PROPERTIES FROM CLASS INSTANCES YOU
 * CANNOT USE THE FAST CLASS MAPPER.
 */
static VALUE mapping_props(VALUE self, VALUE obj) {
    CLASS_MAPPING *map;
    Data_Get_Struct(self, CLASS_MAPPING, map);

    if(TYPE(obj) == T_HASH) {
        return obj;
    }

    // Get "properties"
    VALUE props_ary;
    VALUE klass = CLASS_OF(obj);
    long i, len;
    if(!st_lookup(map->prop_cache, klass, &props_ary)) {
        props_ary = rb_ary_new();

        // Build props array
        VALUE all_methods = rb_class_public_instance_methods(0, NULL, klass);
        VALUE object_methods = rb_class_public_instance_methods(0, NULL, rb_cObject);
        VALUE possible_methods = rb_funcall(all_methods, rb_intern("-"), 1, object_methods);
        len = RARRAY_LEN(possible_methods);
        for(i = 0; i < len; i++) {
            VALUE meth = rb_obj_method(obj, RARRAY_PTR(possible_methods)[i]);
            VALUE arity = rb_funcall(meth, rb_intern("arity"), 0);
            if(FIX2INT(arity) == 0) {
                rb_ary_push(props_ary, RARRAY_PTR(possible_methods)[i]);
            }
        }

        // Store it
        st_add_direct(map->prop_cache, klass, props_ary);
    }

    // Build properties hash using list of properties
    VALUE props = rb_hash_new();
    len = RARRAY_LEN(props_ary);
    for(i = 0; i < len; i++) {
        rb_hash_aset(props, RARRAY_PTR(props_ary)[i], rb_funcall(obj, rb_intern("send"), 1, RARRAY_PTR(props_ary)[i]));
    }

    return props;
}

void Init_rocket_amf_fast_class_mapping() {
    // Define map set
    cFastMappingSet = rb_define_class_under(mRocketAMFExt, "FastMappingSet", rb_cObject);
    rb_define_alloc_func(cFastMappingSet, mapset_alloc);
    rb_define_method(cFastMappingSet, "map", mapset_map, 1);

    // Define FastClassMapping
    VALUE cFastClassMapping = rb_define_class_under(mRocketAMFExt, "FastClassMapping", rb_cObject);
    rb_define_alloc_func(cFastClassMapping, mapping_alloc);
    rb_attr(cFastClassMapping, rb_intern("use_array_collection"), 1, 1, Qtrue);
    rb_define_method(cFastClassMapping, "initialize", mapping_init, 0);
    rb_define_method(cFastClassMapping, "define", mapping_define, 0);
    rb_define_method(cFastClassMapping, "reset", mapping_reset, 0);
    rb_define_method(cFastClassMapping, "get_as_class_name", mapping_as_class_name, 1);
    rb_define_method(cFastClassMapping, "get_ruby_obj", mapping_get_ruby_obj, 1);
    rb_define_method(cFastClassMapping, "populate_ruby_obj", mapping_populate, -1);
    rb_define_method(cFastClassMapping, "props_for_serialization", mapping_props, 1);

    // Cache values
    cTypedHash = rb_const_get(rb_const_get(mRocketAMF, rb_intern("Values")), rb_intern("TypedHash"));
    id_hashset = rb_intern("[]=");
}