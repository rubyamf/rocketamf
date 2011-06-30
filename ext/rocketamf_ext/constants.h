// AMF0 Type Markers
#define AMF0_NUMBER_MARKER        0x00
#define AMF0_BOOLEAN_MARKER       0x01
#define AMF0_STRING_MARKER        0x02
#define AMF0_OBJECT_MARKER        0x03
#define AMF0_MOVIE_CLIP_MARKER    0x04
#define AMF0_NULL_MARKER          0x05
#define AMF0_UNDEFINED_MARKER     0x06
#define AMF0_REFERENCE_MARKER     0x07
#define AMF0_HASH_MARKER          0x08
#define AMF0_OBJECT_END_MARKER    0x09
#define AMF0_STRICT_ARRAY_MARKER  0x0A
#define AMF0_DATE_MARKER          0x0B
#define AMF0_LONG_STRING_MARKER   0x0C
#define AMF0_UNSUPPORTED_MARKER   0x0D
#define AMF0_RECORDSET_MARKER     0x0E
#define AMF0_XML_MARKER           0x0F
#define AMF0_TYPED_OBJECT_MARKER  0x10
#define AMF0_AMF3_MARKER          0x11

// AMF3 Type Markers
#define AMF3_UNDEFINED_MARKER     0x00
#define AMF3_NULL_MARKER          0x01
#define AMF3_FALSE_MARKER         0x02
#define AMF3_TRUE_MARKER          0x03
#define AMF3_INTEGER_MARKER       0x04
#define AMF3_DOUBLE_MARKER        0x05
#define AMF3_STRING_MARKER        0x06
#define AMF3_XML_DOC_MARKER       0x07
#define AMF3_DATE_MARKER          0x08
#define AMF3_ARRAY_MARKER         0x09
#define AMF3_OBJECT_MARKER        0x0A
#define AMF3_XML_MARKER           0x0B
#define AMF3_BYTE_ARRAY_MARKER    0x0C
#define AMF3_DICT_MARKER          0x11

// Other AMF3 Markers
#define AMF3_EMPTY_STRING          0x01
#define AMF3_DYNAMIC_OBJECT        0x0B
#define AMF3_CLOSE_DYNAMIC_OBJECT  0x01
#define AMF3_CLOSE_DYNAMIC_ARRAY   0x01

// Other Constants
#define MAX_INTEGER  268435455
#define MIN_INTEGER  -268435456
#define INITIAL_STREAM_LENGTH 128 // Initial buffer length for serializer output
#define MAX_STREAM_LENGTH 10*1024*1024 // Let's cap it at 10MB for now
#define MAX_ARRAY_PREALLOC 100000