//
//  SpeedCoder.m
//  MMAPKV
//
//  Created by Assassin on 2018/4/9.
//  Copyright © 2018年 PeachRain. All rights reserved.
//

#import "SpeedCoder.h"
#import "DataItem.h"
#import "DataOutput.h"
#import "DataInput.h"

@implementation SpeedCoder {
    NSData* inputData;
    DataInput* inputStream;
}

- (id)initForReadingWithData:(NSData *)data {
    if (self = [super init]) {
        inputData = data;
        inputStream = new DataInput(data);
    }
    return self;
}

#pragma mark ###### 封装成NSData
+(NSData*) encodeDataWithObject:(id)obj {
    if (!obj) {
        return nil;
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableData *allData = [NSMutableData data];
        NSDictionary *dataDic = (NSDictionary*)obj;
        [dataDic enumerateKeysAndObjectsUsingBlock:^(NSString*  _Nonnull key, NSData*  _Nonnull obj, BOOL * _Nonnull stop) {
            //[struct--Key--Data]
            size_t dataSize = obj.length;
            NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
            size_t keySize = keyData.length;
            DataItem item;
            item.keySize = keySize;
            item.valueSize = dataSize;
            NSData *itemData = [[NSData alloc]initWithBytes:&item length:DATAITEM_STRUCT_SZIE];
            [allData appendData:itemData];
            [allData appendData:keyData];
            [allData appendData:obj];
        }];
        DataOutput *mm_output = new DataOutput(allData);
        mm_output->writeRawData(allData);
        return allData;
    }
    return nil;
}

#pragma mark ###### 解封装NSData -> NSDictionary
+(id) decodeFromData:(NSData*)oData {
    
    id obj = nil;
    
    @try{
        SpeedCoder *coder = [[SpeedCoder alloc] initForReadingWithData:oData];
        obj = [coder decodeOneDictionaryFromData];
    }@catch(NSException *exception) {
        NSLog(@"SpeedCoder:decodeFromData -> %@",exception);
    }
    
    return obj;
}

-(NSMutableDictionary*) decodeOneDictionaryFromData{
    NSMutableDictionary* dic = [NSMutableDictionary dictionary];
    
    struct DataItem item; 
    while (!inputStream->isAtEnd()) {
        NSData *itemData = inputStream->readHeadStruct();
        [itemData getBytes:&item length:DATAITEM_STRUCT_SZIE];
        if (item.keySize > 0) {
            NSString *strKey = inputStream->readStringKey(item.keySize);
            if (strKey) {
                id value = inputStream->readData(item.valueSize);
                [dic setObject:value forKey:strKey];
            }
        }
    }
    return dic;
}

@end
