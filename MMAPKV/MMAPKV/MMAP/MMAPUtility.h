//
//  MMAPUtility.h
//  MMAPKV
//
//  Created by Assassin on 2018/4/3.
//  Copyright © 2018年 PeachRain. All rights reserved.
//

#ifdef __cplusplus

#import <Foundation/Foundation.h>

int32_t computeBoolSize(BOOL value);
int32_t computeInt32Size(int32_t value);
int32_t computeUInt32Size(int32_t value);
int32_t computeUInt64Size(int64_t value);
int32_t computeInt64Size(int64_t value);
int32_t computeFloatSize(Float32 value);
int32_t computeDoubleSize(Float64 value);
uint64_t computeStringSize(NSString *value);
int32_t computeFixed32Size(int32_t value);
int32_t computeRawVarint32Size(int32_t value);
int32_t computeRawVarint64Size(int64_t value);

static inline uint32_t convertInt32ToUInt32(int32_t v) {
    union { int32_t i; uint32_t u; } u;
    u.i = v;
    return u.u;
}

static inline int64_t convertUInt32ToInt32(uint32_t v) {
    union { int32_t i; uint32_t u; } u;
    u.u = v;
    return u.i;
}

static inline uint64_t convertInt64ToUInt64(int64_t v) {
    union { int64_t i; uint64_t u; } u;
    u.i = v;
    return u.u;
}


static inline int64_t convertUInt64ToInt64(uint64_t v) {
    union { int64_t i; uint64_t u; } u;
    u.u = v;
    return u.i;
}

static inline int64_t convertFloat64ToInt64(Float64 v) {
    union { Float64 f; int64_t i; } u;
    u.f = v;
    return u.i;
}

static inline int32_t convertFloat32ToInt32(Float32 v) {
    union { Float32 f; int32_t i; } u;
    u.f = v;
    return u.i;
}

static inline Float64 convertInt64ToFloat64(int64_t v) {
    union { Float64 f; int64_t i; } u;
    u.i = v;
    return u.f;
}


static inline Float32 convertInt32ToFloat32(int32_t v) {
    union { Float32 f; int32_t i; } u;
    u.i = v;
    return u.f;
}


static inline int32_t logicalRightShift32(int32_t value, int32_t spaces) {
    return (int32_t)convertUInt32ToInt32((convertInt32ToUInt32(value) >> spaces));
}

static inline int64_t logicalRightShift64(int64_t value, int32_t spaces) {
    return convertUInt64ToInt64((convertInt64ToUInt64(value) >> spaces));
}
    


#endif
