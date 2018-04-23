//
//  DataInput.m
//  MMAPKV
//
//  Created by Assassin on 2018/4/4.
//  Copyright © 2018年 PeachRain. All rights reserved.
//

#import "DataInput.h"
#import "MMAPUtility.h"

DataInput::DataInput(NSData* oData)
: bufferPointer((uint8_t*)oData.bytes), bufferSize((int32_t)oData.length), bufferSizeAfterLimit(0), bufferPos(0)
{
}

DataInput::~DataInput() {
    bufferPointer = NULL;
    bufferSize = 0;
}

int32_t DataInput::readFixed32() {
    return this->readRawLittleEndian32();
}

/** 读取32-bit数据流 */
int32_t DataInput::readRawLittleEndian32() {
    int8_t b1 = this->readRawByte();
    int8_t b2 = this->readRawByte();
    int8_t b3 = this->readRawByte();
    int8_t b4 = this->readRawByte();
    return
    (((int32_t)b1 & 0xff)      ) |
    (((int32_t)b2 & 0xff) <<  8) |
    (((int32_t)b3 & 0xff) << 16) |
    (((int32_t)b4 & 0xff) << 24);
}
int64_t DataInput::readRawLittleEndian64() {
    int8_t b1 = this->readRawByte();
    int8_t b2 = this->readRawByte();
    int8_t b3 = this->readRawByte();
    int8_t b4 = this->readRawByte();
    int8_t b5 = this->readRawByte();
    int8_t b6 = this->readRawByte();
    int8_t b7 = this->readRawByte();
    int8_t b8 = this->readRawByte();
    return
    (((int64_t)b1 & 0xff)      ) |
    (((int64_t)b2 & 0xff) <<  8) |
    (((int64_t)b3 & 0xff) << 16) |
    (((int64_t)b4 & 0xff) << 24) |
    (((int64_t)b5 & 0xff) << 32) |
    (((int64_t)b6 & 0xff) << 40) |
    (((int64_t)b7 & 0xff) << 48) |
    (((int64_t)b8 & 0xff) << 56);
}

int8_t DataInput::readRawByte() {
    if (bufferPos == bufferSize) {
        NSString *reason = [NSString stringWithFormat:@"reach end, bufferPos: %d, bufferSize: %d", bufferPos, bufferSize];
        @throw [NSException exceptionWithName:@"InvalidProtocolBuffer" reason:reason userInfo:nil];
        return -1;
    }
    int8_t* bytes = (int8_t*)bufferPointer;
    return bytes[bufferPos++];
}

#pragma mark get

int32_t DataInput::getInt32() {
    return this->readRawVarint32();
}

int32_t DataInput::getUInt32() {
    return this->readRawVarint32();
}

int64_t DataInput::getUInt64() {
    return this->readRawVarint64();
}

int64_t DataInput::getInt64() {
    return this->readRawVarint64();
}

BOOL DataInput::getBool() {
    return this->readRawVarint32() != 0;
}

Float64 DataInput::getDouble() {
    return convertInt64ToFloat64(this->readRawLittleEndian64());
}

Float32 DataInput::getFloat() {
    return convertInt32ToFloat32(this->readRawLittleEndian32());
}

NSString* DataInput::getString() {
    return [[NSString alloc] initWithBytes:bufferPointer
                                                       length:bufferSize
                                                     encoding:NSUTF8StringEncoding];
}

int32_t DataInput::readRawVarint32() {
    int8_t tmp = this->readRawByte();
    if (tmp >= 0) {
        return tmp;
    }
    int32_t result = tmp & 0x7f;//01111111 改变bit7的01
    if ((tmp = this->readRawByte()) >= 0) {
        result |= tmp << 7;
    } else {
        result |= (tmp & 0x7f) << 7;
        if ((tmp = this->readRawByte()) >= 0) {
            result |= tmp << 14;
        } else {
            result |= (tmp & 0x7f) << 14;
            if ((tmp = this->readRawByte()) >= 0) {
                result |= tmp << 21;
            } else {
                result |= (tmp & 0x7f) << 21;
                result |= (tmp = this->readRawByte()) << 28;
                if (tmp < 0) {
                    for (int i = 0; i < 5; i++) {
                        if (this->readRawByte() >= 0) {
                            return result;
                        }
                    }
                    @throw [NSException exceptionWithName:@"InvalidProtocolBuffer" reason:@"malformedVarint" userInfo:nil];
                    return -1;
                }
            }
        }
    }
    return result;
}

int64_t DataInput::readRawVarint64() {
    int32_t shift = 0;
    int64_t result = 0;
    while (shift < 64) {
        int8_t b = this->readRawByte();
        result |= (int64_t)(b & 0x7F) << shift;
        if ((b & 0x80) == 0) {
            return result;
        }
        shift += 7;
    }

    @throw [NSException exceptionWithName:@"readRawVarint64" reason:@"malformedVarint" userInfo:nil];
    return -1;
}

/** 读取每个数据的头信息 */
NSData* DataInput::readHeadStruct() {
    
    size_t size = 16;
    return this->readData(size);
    
}

NSData* DataInput::readData(size_t size) {
    if (size <= (bufferSize - bufferPos) && size > 0) {
        NSData* result = [NSData dataWithBytes:(bufferPointer + bufferPos) length:size];
        bufferPos += size;
        return result;
    } else {
        return nil;
        // 超过容量了，后面处理
    }
}

NSString* DataInput::readStringKey(size_t size) {
    if (size <= (bufferSize - bufferPos) && size > 0) {

        NSString* result = [[NSString alloc] initWithBytes:(bufferPointer + bufferPos)
                                                    length:size
                                                  encoding:NSUTF8StringEncoding];
        bufferPos += size;
        return result;
    } else {
        return nil;
    }
}
