//
//  MMAPUtility.m
//  MMAPKV
//
//  Created by Assassin on 2018/4/3.
//  Copyright © 2018年 PeachRain. All rights reserved.
//

#import "MMAPUtility.h"

static const int32_t LITTLE_ENDIAN_32_SIZE = 4;
static const int32_t LITTLE_ENDIAN_64_SIZE = 8;
static const int32_t DATAITEM_STRUCT_32_SIZE = 16;

//@int32
int32_t computeFixed32Size(int32_t value) {
    return LITTLE_ENDIAN_32_SIZE;
}

//@DataItm
int32_t computeDataItem32Size() {
    return DATAITEM_STRUCT_32_SIZE;
}

//@BOOL
int32_t computeBoolSize(BOOL value) {
    return 1;
}

//@int32
int32_t computeInt32Size(int32_t value) {
    if (value >= 0) {
        return computeRawVarint32Size(value);
    } else {
        return 10;
    }
}

//@uint32
int32_t computeUInt32Size(int32_t value) {
    return computeRawVarint32Size(value);
}

//@uint64
int32_t computeUInt64Size(int64_t value) {
    return computeRawVarint64Size(value);
}

//@int64
int32_t computeInt64Size(int64_t value) {
    return computeRawVarint64Size(value);
}

//@float
int32_t computeFloatSize(Float32 value) {
    return LITTLE_ENDIAN_32_SIZE;
}

//@double
int32_t computeDoubleSize(Float64 value) {
    return LITTLE_ENDIAN_64_SIZE;
}

//@string
uint64_t computeStringSize(NSString *value) {
    return [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
}



int32_t computeRawVarint32Size(int32_t value) {
    if ((value & (0xffffffff <<  7)) == 0) return 1;
    if ((value & (0xffffffff << 14)) == 0) return 2;
    if ((value & (0xffffffff << 21)) == 0) return 3;
    if ((value & (0xffffffff << 28)) == 0) return 4;
    return 5;
}

int32_t computeRawVarint64Size(int64_t value) {
    if ((value & (0xffffffffffffffffL <<  7)) == 0) return 1;
    if ((value & (0xffffffffffffffffL << 14)) == 0) return 2;
    if ((value & (0xffffffffffffffffL << 21)) == 0) return 3;
    if ((value & (0xffffffffffffffffL << 28)) == 0) return 4;
    if ((value & (0xffffffffffffffffL << 35)) == 0) return 5;
    if ((value & (0xffffffffffffffffL << 42)) == 0) return 6;
    if ((value & (0xffffffffffffffffL << 49)) == 0) return 7;
    if ((value & (0xffffffffffffffffL << 56)) == 0) return 8;
    if ((value & (0xffffffffffffffffL << 63)) == 0) return 9;
    return 10;
}
