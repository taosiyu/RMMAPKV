//
//  DataInput.h
//  MMAPKV
//
//  Created by Assassin on 2018/4/4.
//  Copyright © 2018年 PeachRain. All rights reserved.
//
#ifdef __cplusplus

#import <Foundation/Foundation.h>

//读取用
class DataInput {
    uint8_t* bufferPointer;
    int32_t bufferSize;
    int32_t bufferSizeAfterLimit;
    int32_t bufferPos;
    
public:
    DataInput(NSData* oData);
    ~DataInput();
    
    bool isAtEnd() { return bufferPos == bufferSize; };
    
    int32_t readFixed32();
    int32_t readRawLittleEndian32();
    int64_t readRawLittleEndian64();
    
    NSString* readStringKey(size_t size);
    
    NSData* readData(size_t size);
    
    /**
     *@读取每个数据的头信息
     **/
    NSData* readHeadStruct();
    
    /**
     *@每次读取一个bit
     **/
    int8_t readRawByte();
    
    int32_t readRawVarint32();
    int64_t readRawVarint64();
    
    
    int32_t getInt32();
    int32_t getUInt32();
    int64_t getUInt64();
    int64_t getInt64();
    BOOL getBool();
    Float64 getDouble();
    Float32 getFloat();
    NSString* getString();
    
};

#endif


