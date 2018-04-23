//
//  DataOutput.h
//  MMAPKV
//
//  Created by Assassin on 2018/4/4.
//  Copyright © 2018年 PeachRain. All rights reserved.
//
#ifdef __cplusplus

#import <Foundation/Foundation.h>

//写入用
class DataOutput {
    uint8_t* bufferPointer;
    size_t bufferLength;
    int32_t position;
    
public:
    DataOutput(void* ptr, size_t len);
    DataOutput(NSMutableData* oData);
    ~DataOutput();
    
    /**
     *@获取空闲空间大小
     **/
    int32_t freeSpace();
    
    void writeFixed32(int32_t value);
    void writeRawLittleEndian32(int32_t value);
    void writeRawLittleEndian64(int64_t value);
    
    void writeRawData(NSData* data);
    void writeRawData(NSData* value, int32_t offset, int32_t length);
    
    //字符转字节写入指定buffer
    void writeString(NSString* value);
    void writeData(NSData* value);
    
    /*
     *@写入一个bit
     */
    void writeRawByte(uint8_t value);
    
    //int32
    void writeInt32(int32_t value);
    void writeRawVarint32(int32_t value);
    void writeRawVarint64(int64_t value);
    
    //uint32
    void writeUInt32(int32_t value);
    
    //uint64
    void writeUInt64(int64_t value);
    
    //int64
    void writeInt64(int64_t value);
    
    //bool
    void writeBool(BOOL value);
    
    //double
    void writeDouble(Float64 value);
    
    //float
    void writeFloat(Float32 value);
    
    //string
    void writeStringValue(NSString *value,NSUInteger stringSize);
    
    
    //指针移动
    void seek(size_t addedSize);
};

#endif
