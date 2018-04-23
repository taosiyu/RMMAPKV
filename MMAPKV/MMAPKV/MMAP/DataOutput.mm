//
//  DataOutput.m
//  MMAPKV
//
//  Created by Assassin on 2018/4/4.
//  Copyright © 2018年 PeachRain. All rights reserved.
//

#import "DataOutput.h"
#import "MMAPUtility.h"

#pragma mark 初始化方法
DataOutput::DataOutput(void* ptr, size_t len) {
    bufferPointer = (uint8_t*)ptr;
    bufferLength = len;
    position = 0;
}

DataOutput::DataOutput(NSMutableData* oData) {
    bufferPointer = (uint8_t*)oData.mutableBytes;
    bufferLength = oData.length;
    position = 0;
}

DataOutput::~DataOutput() {
    bufferPointer = NULL;
    position = 0;
}

int32_t DataOutput::freeSpace() {
    return int32_t(bufferLength - position);
}


void DataOutput::writeFixed32(int32_t value) {
    this->writeRawLittleEndian32(value);
}

//写入一个bit
void DataOutput::writeRawByte(uint8_t value) {
    if (position == bufferLength) {
        NSString *reason = [NSString stringWithFormat:@"position: %d, bufferLength: %u", position, (unsigned int)bufferLength];
        @throw [NSException exceptionWithName:@"OutOfSpace" reason:reason userInfo:nil];
    }
    
    bufferPointer[position++] = value;
}

void DataOutput::writeInt32(int32_t value) {
    if (value >= 0) {
        this->writeRawVarint32(value);
    }else {
        this->writeRawVarint64(value);
    }
}

void DataOutput::writeUInt32(int32_t value) {
    this->writeRawVarint32(value);
}

void DataOutput::writeUInt64(int64_t value) {
    this->writeRawVarint64(value);
}

void DataOutput::writeInt64(int64_t value) {
    this->writeRawVarint64(value);
}

void DataOutput::writeBool(BOOL value) {
    this->writeRawByte(value ? 1 : 0);
}

void DataOutput::writeDouble(Float64 value) {
    this->writeRawLittleEndian64(convertFloat64ToInt64(value));
}

void DataOutput::writeFloat(Float32 value) {
    this->writeRawLittleEndian32(convertFloat32ToInt32(value));
}

void DataOutput::writeStringValue(NSString *value,NSUInteger stringSize) {
    [value getBytes:bufferPointer
          maxLength:stringSize
         usedLength:0
           encoding:NSUTF8StringEncoding
            options:0
              range:NSMakeRange(0, value.length)
     remainingRange:NULL];
    position += stringSize;
}


void DataOutput::writeRawVarint32(int32_t value) {
    while (YES) {
        //value & ~01111111(10000000)
        if ((value & ~0x7F) == 0) {
            this->writeRawByte(value);
            return;
        } else {
            //0x80 = 10000000 ,0x7f = 01111111
            // | 0x80为了将最高位变位,&0x7F 为了获得7位
            this->writeRawByte((value & 0x7F) | 0x80);
            value = logicalRightShift32(value, 7);
        }
    }
}

void DataOutput::writeRawVarint64(int64_t value) {
    while (YES) {
        //0x7FL 最后的L表示强制编译器把常量作为长整数来处理
        if ((value & ~0x7FL) == 0) {
            this->writeRawByte((int32_t) value);
            return;
        } else {
            this->writeRawByte(((int32_t) value & 0x7F) | 0x80);
            value = logicalRightShift64(value, 7);
        }
    }
}

void DataOutput::writeRawLittleEndian32(int32_t value) {
    //0xFF = 1111 1111
    this->writeRawByte((value      ) & 0xFF);
    this->writeRawByte((value >>  8) & 0xFF);
    this->writeRawByte((value >> 16) & 0xFF);
    this->writeRawByte((value >> 24) & 0xFF);
}

void DataOutput::writeRawLittleEndian64(int64_t value) {
    this->writeRawByte((int32_t)(value      ) & 0xFF);
    this->writeRawByte((int32_t)(value >>  8) & 0xFF);
    this->writeRawByte((int32_t)(value >> 16) & 0xFF);
    this->writeRawByte((int32_t)(value >> 24) & 0xFF);
    this->writeRawByte((int32_t)(value >> 32) & 0xFF);
    this->writeRawByte((int32_t)(value >> 40) & 0xFF);
    this->writeRawByte((int32_t)(value >> 48) & 0xFF);
    this->writeRawByte((int32_t)(value >> 56) & 0xFF);
}

void DataOutput::writeRawData(NSData* data) {
    this->writeRawData(data, 0, (int32_t)data.length);
}


void DataOutput::writeRawData(NSData* value, int32_t offset, int32_t length) {
    if (bufferLength - position >= length) {
        //填充数据
        memcpy(bufferPointer + position, ((uint8_t*)value.bytes) + offset, length);
        position += length;
    } else {
        [NSException exceptionWithName:@"Space" reason:@"too much data than calc" userInfo:nil];
    }
}

//字符转字节写入指定buffer
void DataOutput::writeString(NSString* value) {
    NSUInteger numberOfBytes = [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    this->writeRawVarint32((int32_t)numberOfBytes);
    //    memcpy(bufferPointer + position, ((uint8_t*)value.bytes), numberOfBytes);
    [value getBytes:bufferPointer + position
          maxLength:numberOfBytes
     
         usedLength:0
           encoding:NSUTF8StringEncoding
            options:0
              range:NSMakeRange(0, value.length)
     remainingRange:NULL];
    position += numberOfBytes;
}

void DataOutput::writeData(NSData* value) {
    this->writeRawVarint32((int32_t)value.length);
    this->writeRawData(value);
}


void DataOutput::seek(size_t addedSize) {
    position += addedSize;
    
    if (position > bufferLength) {
        @throw [NSException exceptionWithName:@"OutOfSpace" reason:@"" userInfo:nil];
    }
}

