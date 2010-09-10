// Before RFLOAT_VALUE, value was in a different place in the struct
#ifndef RFLOAT_VALUE
#define RFLOAT_VALUE(v) (RFLOAT(v)->value)
#endif